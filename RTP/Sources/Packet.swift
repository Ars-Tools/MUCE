//
//  Packet.swift
//  MUCE
//
//  Created by Kota on 4/8/R7.
//
public struct Packet: Sendable {
	public enum Error: Swift.Error {
		case status
		case version
		case type
		case sequence
		case timestamp
		case synchronization
		case contributors
		case`extension`
		case padding
	}
	@usableFromInline let status: Status
	@usableFromInline let type: `Type`
	@usableFromInline let sequence: UInt16
	@usableFromInline let timestamp: UInt32
	@usableFromInline let synchronization: UInt32
	@usableFromInline let contributions: Array<UInt32>
	@usableFromInline let extensions: Optional<Extension>
	@usableFromInline let payload: Array<UInt8>
}
extension Packet {
	public init(
		source: UInt32,
		contributions: Array<UInt32>,
		sequence: UInt16,
		timestamp: UInt32,
		type: `Type`,
		payload: Array<UInt8>) {
			status = [.init(version: 2),.Padding]
			self.type = type
			self.sequence = sequence
			self.timestamp = timestamp
			self.synchronization = source
			self.contributions = contributions
			self.extensions = .none
			self.payload = payload
	}
	public init(
		source: UInt32,
		contributions: Array<UInt32>,
		sequence: UInt16,
		timestamp: UInt32,
		type: `Type`,
		payload: Array<UInt8>,
		extension: Extension) {
			status = [.init(version: 2),.Padding,.Extension]
			self.type = type
			self.sequence = sequence
			self.timestamp = timestamp
			self.synchronization = source
			self.contributions = contributions
			self.extensions = .some(`extension`)
			self.payload = payload
	}
}
extension Packet {
	public init<T>(from rawValue: T) throws (Error) where T: Collection<UInt8>, T.SubSequence == T.SubSequence.SubSequence {
		try self.init(from: rawValue.prefix(.max))
	}
	public init<T>(from rawValue: T) throws (Error) where T: Collection<UInt8>, T.SubSequence == T {
		var cursor = rawValue
		status = switch cursor.popFirst() {
		case.some(let value):
			.init(rawValue: value)
		case.none:
			throw.status
		}
		guard status.version == 2 else { throw.version }
		type = switch cursor.popFirst() {
		case.some(let value):
			.init(rawValue: value)
		case.none:
			throw.type
		}
		sequence = switch cursor.popElement().map(UInt16.init(bigEndian:)) {
		case.some(let value):
			value
		case.none:
			throw.sequence
		}
		timestamp = switch cursor.popElement().map(UInt32.init(bigEndian:)) {
		case.some(let field):
			field
		case.none:
			throw.timestamp
		}
		synchronization = switch cursor.popElement().map(UInt32.init(bigEndian:)) {
		case.some(let field):
			field
		case.none:
			throw.synchronization
		}
		contributions = repeatElement((), count: .init(truncatingIfNeeded: status.channel)).compactMap {
			cursor.popElement()
		}
		guard contributions.count == status.channel else { throw.contributors }
		if status.contains(.Extension) {
			extensions = switch Extension(parse: &cursor) {
			case.some(let value):
				.some(value)
			case.none:
				throw.extension
			}
		} else {
			extensions = .none
		}
		if status.contains(.Padding) {
			payload = switch cursor.suffix(1).first {
			case.some(let value):
				.init(cursor.dropLast(.init(value)))
			case.none:
				throw.padding
			}
		} else {
			payload = .init(cursor)
		}
	}
}
extension Packet {
	public func encode() -> ArraySlice<UInt8> {
		var packet = ([
			[
				status.rawValue,
				type.rawValue,
			],
			withUnsafeBytes(of: sequence.bigEndian, Array<UInt8>.init),
			withUnsafeBytes(of: timestamp.bigEndian, Array<UInt8>.init),
			withUnsafeBytes(of: synchronization.bigEndian, Array<UInt8>.init),
			contributions.flatMap {
				withUnsafeBytes(of: $0, Array<UInt8>.init)
			},
			extensions.encode(),
			payload
		] as Array<Array<UInt8>>).flatMap(\.self)
		if status.contains(.Padding) {
			let count = 3 - packet.count % 4
			packet.append(contentsOf: repeatElement(0, count: count))
			packet.append(.init(count + 1))
		}
		return.init(packet)
	}
}
extension Packet: Codable {
	public init(from decoder: any Decoder) throws {
		try self.init(from: decoder.singleValueContainer().decode(Array<UInt8>.self)[0...])
	}
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(Array(encode()))
	}
}
extension Packet: Hashable {
	public static func==(lhs: Self, rhs: Self) -> Bool {
		[
			lhs.status == rhs.status,
			lhs.type == rhs.type,
			lhs.sequence == rhs.sequence,
			lhs.timestamp == rhs.timestamp,
			lhs.synchronization == rhs.synchronization,
			lhs.contributions == rhs.contributions,
			lhs.extensions == rhs.extensions,
			lhs.payload == rhs.payload,
		].allSatisfy(\.self)
	}
	public func hash(into hasher: inout Hasher) {
		encode().hash(into: &hasher)
	}
}
extension Packet {
	@dynamicMemberLookup
	public struct Status: Sendable & RawRepresentable {
		public typealias RawValue = UInt8
		public let rawValue: UInt8
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
	}
}
extension Packet.Status {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension Packet.Status: OptionSet {
	public static let Padding   = Self(rawValue: 0b0010_0000)
	public static let Extension = Self(rawValue: 0b0001_0000)
}
extension Packet.Status {
	public init(version: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: (version << 6) & 0b1100_0000)
	}
	public var version: Int {
		.init(truncatingIfNeeded: (rawValue & 0b1100_0000) >> 6)
	}
}
extension Packet.Status {
	public init(channel: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: channel << 0) & 0b0000_1111
	}
	public var channel: Int {
		.init(truncatingIfNeeded: (rawValue & 0b0000_1111) >> 0)
	}
}
extension Packet {
	@dynamicMemberLookup
	public struct `Type`: RawRepresentable, Sendable {
		public typealias RawValue = UInt8
		public let rawValue: UInt8
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
	}
}
extension Packet.`Type` {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension Packet.`Type` {
	public static let PCMU    = Self(rawValue: 0)
	public static let GSM     = Self(rawValue: 3)
	public static let G723    = Self(rawValue: 4)
	public static let DVI4_8  = Self(rawValue: 5)
	public static let DVI4_16 = Self(rawValue: 6)
	public static let LPC     = Self(rawValue: 7)
	public static let PCMA    = Self(rawValue: 8)
	public static let G722    = Self(rawValue: 9)
	public static let L16_2ch = Self(rawValue: 10)
	public static let L16_1ch = Self(rawValue: 11)
	public static let QCELP   = Self(rawValue: 12)
	public static let CN      = Self(rawValue: 13)
	public static let MPA     = Self(rawValue: 14)
	public static let G728    = Self(rawValue: 15)
	public static let DVI4_11 = Self(rawValue: 16)
	public static let DVI4_22 = Self(rawValue: 17)
	public static let G729    = Self(rawValue: 18)
	public static let CelB    = Self(rawValue: 25)
	public static let JPEG    = Self(rawValue: 26)
	public static let nv      = Self(rawValue: 28)
	public static let H261    = Self(rawValue: 31)
	public static let MPV     = Self(rawValue: 32)
	public static let MP2T    = Self(rawValue: 33)
	public static let H263    = Self(rawValue: 34)
}
extension Packet {
	public struct Extension: Sendable {
		@usableFromInline
		let profile: UInt16
		@usableFromInline
		let payload: Array<UInt8>
	}
}
extension Packet.Extension {
	init?<T>(parse: inout T) where T: Collection, T.SubSequence == T, T.Element == UInt8 {
		guard let head = parse.popElement() as Optional<UInt16> else {
			return nil
		}
		profile = head
		guard let size = parse.popElement().map(UInt16.init(bigEndian:)).flatMap(Int.init(exactly:)), let body = parse.popPayload(count: size) else {
			return nil
		}
		payload = .init(body)
	}
}
extension Optional where Wrapped == Packet.Extension {
	public static func==(lhs: Optional<Packet.Extension>, rhs: Optional<Packet.Extension>) -> Bool {
		switch (lhs, rhs) {
		case (.some(let lhs),.some(let rhs)):
			[
				lhs.profile == rhs.profile,
				lhs.payload == rhs.payload
			].allSatisfy(\.self)
		case (.none, .none):
			true
		case (.some, .none), (.none, .some):
			false
		}
	}
	func encode() -> Array<UInt8> {
		map {
			withUnsafeBytes(of: $0.profile, Array<UInt8>.init) +
			withUnsafeBytes(of: UInt16(truncatingIfNeeded: $0.payload.count).bigEndian, Array<UInt8>.init) + 
			$0.payload
		} ?? []
	}
}
extension Collection where Element == UInt8, SubSequence == Self {
	mutating func popElement<T: FixedWidthInteger & BitwiseCopyable>() -> Optional<T> {
		popPayload(count: MemoryLayout<T>.size).flatMap {
			$0.withContiguousStorageIfAvailable {
				UnsafeRawBufferPointer($0).loadUnaligned(as: T.self)
			}
		}
	}
	mutating func popPayload(count: Int) -> Optional<SubSequence> {
		switch prefix(count) {
		case let prefix where prefix.count == count:
			trimPrefix(prefix)
			return.some(prefix)
		default:
			return.none
		}
	}
}
