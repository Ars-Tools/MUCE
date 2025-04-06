//
//  Packet.swift
//  MUCE
//
//  Created by Kota on 3/31/R7.
//
public enum Packet: Sendable {
	case Message(address: String, arguments: Array<Argument>)
	case Bundle(timestamp: TimeTag, packets: Array<Packet>)
}
extension Packet {
	public init(address: some StringProtocol, with arguments: some Sequence<Argument> = []) {
		self = .Message(address: address.replacingOccurrences(of: "\0", with: ""), arguments: .init(arguments))
	}
	public init(messages: some Sequence<(some StringProtocol, some Sequence<Argument>)>, at timestamp: TimeTag = .immediately) {
		self = .Bundle(timestamp: timestamp, packets: messages.map(Self.init(address:with:)))
	}
}
extension Packet {
	public init?(decode data: some RangeReplaceableCollection<UInt8>, context: Context = .default) {
		var data = data
		guard let bundle = data.pop(until: 0) else { return nil }
		data.removeFirst(4 - bundle.count % 4)
		switch String(decoding: bundle, as: UTF8.self) {
		case "#bundle":
			guard let timestamp = data.pop().map(TimeTag.RawValue.init(bigEndian:)).flatMap(TimeTag.init(rawValue:)) else { return nil }
			var packets = Array<Packet>()
			while let count = data.pop().map(UInt32.init(bigEndian:)).flatMap(Int.init(exactly:)) {
				guard let chunk = data.pop(count: count), let payload = Packet(decode: chunk, context: context) else { return nil }
				packets.append(payload)
			}
			self = .Bundle(timestamp: timestamp, packets: packets)
		case let address:
			guard let head = data.pop(until: 0) else { return nil }
			data.removeFirst(4 - head.count % 4)
			var tags = Substring(decoding: head, as: UTF8.self)
			guard "," == tags.removeFirst() else { return nil }
			var payload = (tags: "[" + tags + "]" as Substring, data: data)
			guard let arguments = Array<Argument>(decode: &payload, context: context) else { return nil }
			self = .Message(address: address, arguments: arguments)
		}
	}
	public func encode<Data: RangeReplaceableCollection<UInt8>>() -> Data {
		switch self {
		case.Bundle(let time, let packets):
			var data = Data()
			"#bundle".withCString(encodedAs: UTF8.self) {
				let whole = UnsafeBufferPointer(start: $0, count: .max)
				guard let value = whole.firstIndex(of: 0).map(whole.prefix(upTo:)) else { return }
				data.append(contentsOf: value)
				data.append(contentsOf: repeatElement(0, count: 4 - value.count % 4))
			}
			withUnsafeBytes(of: time.rawValue.bigEndian) {
				data.append(contentsOf: $0)
			}
			assert(data.count == 16)
			for packet in packets {
				let value = packet.encode() as Data
				guard let count = UInt32(exactly: value.count) else { continue }
				withUnsafeBytes(of: count.bigEndian) {
					data.append(contentsOf: $0)
				}
				data.append(contentsOf: value)
				data.append(contentsOf: repeatElement(0, count: 3 - ( 3 + value.count ) % 4))
			}
			return data
		case.Message(let address, let arguments):
			var data = Data()
			address.withCString(encodedAs: UTF8.self) {
				let whole = UnsafeBufferPointer(start: $0, count: .max)
				guard let value = whole.firstIndex(of: 0).map(whole.prefix(upTo:)) else { return }
				data.append(contentsOf: value)
				data.append(contentsOf: repeatElement(0, count: 4 - value.count % 4))
			}
			var payload = (tags: "," as Substring, data: Data())
			arguments.forEach {
				$0.encode(into: &payload)
			}
			payload.tags.withCString(encodedAs: UTF8.self) {
				let whole = UnsafeBufferPointer(start: $0, count: .max)
				guard let value = whole.firstIndex(of: 0).map(whole.prefix(upTo:)) else { return }
				data.append(contentsOf: value)
				data.append(contentsOf: repeatElement(0, count: 4 - value.count % 4))
			}
			data.append(contentsOf: payload.data)
			data.append(contentsOf: repeatElement(0, count: 3 - ( 3 + payload.data.count ) % 4))
			return data
		}
	}
}
extension Packet: CustomStringConvertible {
	public var description: String {
		switch self {
		case.Message(let address, let arguments):
			"\(address) \(arguments)"
		case.Bundle(let time, let packets):
			"\(packets)@\(time)"
		}
	}
}
extension Packet {
	public typealias Element = (String, Array<Argument>, TimeTag)
}
extension Packet: Sequence {
	public struct Iterator: IteratorProtocol & Sendable {
		@usableFromInline
		var stack: Array<(Packet, TimeTag)>
		public mutating func next() -> Optional<Element> {
			while let (body, time) = stack.popLast() {
				switch body {
				case.Message(let addr, let args):
					return.some((addr, args, time))
				case.Bundle(let time, let body):
					stack.append(contentsOf: body.reversed().lazy.map { ($0, time) })
				}
			}
			return.none
		}
	}
	public func makeIterator() -> Iterator {
		.init(stack: [(self, .immediately)])
	}
}
extension Packet: AsyncSequence {
	public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
	@inlinable
	func dfs<E: Error>(at timesatmp: TimeTag, execute body: (String, Array<Argument>, TimeTag) throws(E) -> Void) rethrows {
		switch self {
		case.Message(let address, let arguments):
			try body(address, arguments, timesatmp)
		case.Bundle(let timesatmp, let packets):
			for packet in packets {
				try packet.dfs(at: timesatmp, execute: body)
			}
		}
	}
	public func makeAsyncIterator() -> AsyncIterator {
		AsyncStream { folder in
			dfs(at: .immediately) {
				folder.yield(($0, $1, $2))
			}
			folder.finish()
		}.makeAsyncIterator()
	}
}
