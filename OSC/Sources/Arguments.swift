//
//  Arguments.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
public protocol Argument: Sendable {
	init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context)
	func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>))
}
extension Int32: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("i") = payload.tags.first, let value = payload.data.pop().map(UInt32.init(bigEndian:)) else { return nil }
		self.init(bitPattern: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("i")
	}
}
extension Float32: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("f") = payload.tags.first, let value = payload.data.pop().map(UInt32.init(bigEndian:)) else { return nil }
		self.init(bitPattern: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: bitPattern.bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("f")
	}
}
extension StringProtocol {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("s") = payload.tags.first, let value = payload.data.pop(until: 0) else { return nil }
		self.init(decoding: value, as: UTF8.self)
		payload.data.removeFirst(4 - value.count % 4)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withCString(encodedAs: UTF8.self) {
			let whole = UnsafeBufferPointer(start: $0, count: .max)
			let value = whole.firstIndex(of: 0).map(whole.prefix(upTo:)).unsafelyUnwrapped
			payload.data.append(contentsOf: value)
			payload.data.append(contentsOf: repeatElement(0, count: 4 - value.count % 4))
			payload.tags.append("s")
		}
	}
}
extension String: Argument {}
extension Substring: Argument {}
extension RangeReplaceableCollection<UInt8> {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("b") = payload.tags.first, let count = payload.data.pop().map(UInt32.init(bigEndian:)).map(Int.init(truncatingIfNeeded:)) else { return nil }
		self.init(payload.data.prefix(count))
		payload.data.removeFirst(3 - ( 3 + count ) % 4)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: UInt32(truncatingIfNeeded: count).bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.data.append(contentsOf: self)
		payload.data.append(contentsOf: repeatElement(0, count: 3 - ( 3 + count ) % 4))
		payload.tags.append("b")
	}
}
extension Blob: Argument {}
extension Int64: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("h") = payload.tags.first, let value = payload.data.pop().map(UInt64.init(bigEndian:)) else { return nil }
		self.init(bitPattern: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("h")
	}
}
extension Float64: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("d") = payload.tags.first, let value = payload.data.pop().map(UInt64.init(bigEndian:)) else { return nil }
		self.init(bitPattern: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: bitPattern.bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("d")
	}
}
extension Symbol: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("S") = payload.tags.first, let value = payload.data.pop(until: 0) else { return nil }
		self.init(decoding: value, as: UTF8.self)
		payload.data.removeFirst(4 - value.count % 4)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withCString(encodedAs: UTF8.self) {
			let whole = UnsafeBufferPointer(start: $0, count: .max)
			let value = whole.firstIndex(of: 0).map(whole.prefix(upTo:)).unsafelyUnwrapped
			payload.data.append(contentsOf: value)
			payload.data.append(contentsOf: repeatElement(0, count: 4 - value.count % 4))
			payload.tags.append("S")
		}
	}
}
extension Character: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("c") = payload.tags.first, let value = payload.data.pop().map(UInt32.init(bigEndian:)).flatMap(Unicode.Scalar.init) else { return nil }
		self.init(value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: UInt32(unicodeScalars.first.unsafelyUnwrapped).bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("c")
	}
}
extension Color: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("r") = payload.tags.first, let value: RawValue = payload.data.pop() else { return nil }
		self.init(rawValue: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: rawValue) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("r")
	}
}
extension MIDIMessage: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("m") = payload.tags.first, let value: RawValue = payload.data.pop() else { return nil }
		self.init(rawValue: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: rawValue) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("m")
	}
}
extension TimeTag: Argument {
//	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("t") = payload.tags.first, let value = payload.data.pop().map(UInt64.init(bigEndian:)) else { return nil }
		self.init(rawValue: value)
		payload.tags.removeFirst()
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		withUnsafeBytes(of: rawValue.bigEndian) {
			payload.data.append(contentsOf: $0)
		}
		payload.tags.append("t")
	}
}
typealias Arguments = RangeReplaceableCollection<Argument>
extension Arguments {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("[") = payload.tags.first else { return nil }
		payload.tags.removeFirst()
		self.init()
		while let tag = payload.tags.first {
			switch tag {
			case "]":
				payload.tags.removeFirst()
				return
			case let tag:
				switch context[tag]?.init(decode: &payload, context: context) {
				case.some(let element):
					append(element)
				case.none:
					break
				}
			}
		}
		return nil
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		payload.tags.append("[")
		forEach {
			$0.encode(into: &payload)
		}
		payload.tags.append("]")
	}
}
extension Array<Argument>: Argument {}
extension ArraySlice<Argument>: Argument {}
extension Bool: Argument {
	@inlinable
	public init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		switch payload.tags.first {
		case.some("T"):
			self.init(true)
			payload.tags.removeFirst()
		case.some("F"):
			self.init(false)
			payload.tags.removeFirst()
		case.some,.none:
			return nil
		}
	}
	@inlinable
	public func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		payload.tags.append(self ? "T" : "F")
	}
}
struct Impulse {}
extension Impulse: Argument {
	@inlinable
	init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("I") = payload.tags.first else { return nil }
		payload.tags.removeFirst()
	}
	@inlinable
	func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		payload.tags.append("I")
	}
}
struct Nil {}
extension Nil: Argument {
	@inlinable
	init?(decode payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>), context: Context) {
		guard case.some("N") = payload.tags.first else { return nil }
		payload.tags.removeFirst()
	}
	@inlinable
	func encode(into payload: inout (tags: Substring, data: some RangeReplaceableCollection<UInt8>)) {
		payload.tags.append("N")
	}
}
extension Nil {
	public static func==(lhs: Self, rhs: ()) -> Bool {
		true
	}
	public static func==(lhs: (), rhs: Self) -> Bool {
		true
	}
	public static func==(lhs: Self, rhs: Self) -> Bool {
		true
	}
}
