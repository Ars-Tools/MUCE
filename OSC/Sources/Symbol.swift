//
//  Symbol.swift
//  MUCE
//
//  Created by Kota on 4/1/R7.
//
@dynamicMemberLookup
@frozen public struct Symbol: RawRepresentable & Sendable {
	public typealias RawValue = Substring
	public var rawValue: RawValue
	public init(rawValue: RawValue) {
		self.rawValue = rawValue
	}
}
extension Symbol: Codable {
	public init(from decoder: any Decoder) throws {
		rawValue = try.init(String(from: decoder))
	}
	public func encode(to encoder: any Encoder) throws {
		try String(rawValue).encode(to: encoder)
	}
}
extension Symbol {
	public subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		_read {
			yield rawValue[keyPath: keyPath]
		}
	}
	public subscript<R>(dynamicMember keyPath: WritableKeyPath<RawValue, R>) -> R {
		_read {
			yield rawValue[keyPath: keyPath]
		}
		_modify {
			yield &rawValue[keyPath: keyPath]
		}
	}
}
extension Symbol: RandomAccessCollection {
	public typealias Element = RawValue.Element
	public typealias Index = RawValue.Index
	public var startIndex: Index { rawValue.startIndex }
 	public var endIndex: Index { rawValue.endIndex }
	public func index(before i: Index) -> Index {
 		rawValue.index(before: i)
 	}
	public func index(after i: Index) -> Index {
 		rawValue.index(after: i)
 	}
	public subscript(position: Index) -> Element {
		rawValue[position]
	}
	public subscript(bounds: Range<Index>) -> Self {
		.init(rawValue: rawValue[bounds])
	}
}
extension Symbol: ExpressibleByStringLiteral {
	public init(stringLiteral value: StringLiteralType) {
		rawValue = .init(stringLiteral: value)
	}
}
extension Symbol: StringProtocol {
	public init<C, Encoding>(decoding codeUnits: C, as sourceEncoding: Encoding.Type) where C : Collection, Encoding : _UnicodeEncoding, C.Element == Encoding.CodeUnit {
		rawValue = .init(decoding: codeUnits, as: sourceEncoding)
	}
}
extension Symbol {
	public init(_ description: String) {
		rawValue = .init(description)
	}
	public var description: String {
		rawValue.description
	}
}
extension Symbol {
	public init(cString nullTerminatedUTF8: UnsafePointer<CChar>) {
		rawValue = .init(cString: nullTerminatedUTF8)
	}
	public func withCString<Result>(_ body: (UnsafePointer<CChar>) throws -> Result) rethrows -> Result {
		try rawValue.withCString(body)
	}
}
extension Symbol {
	public init<Encoding>(decodingCString nullTerminatedCodeUnits: UnsafePointer<Encoding.CodeUnit>, as sourceEncoding: Encoding.Type) where Encoding : _UnicodeEncoding {
		rawValue = .init(decodingCString: nullTerminatedCodeUnits, as: sourceEncoding)
	}
	public func withCString<Result, Encoding>(encodedAs targetEncoding: Encoding.Type, _ body: (UnsafePointer<Encoding.CodeUnit>) throws -> Result) rethrows -> Result where Encoding : _UnicodeEncoding {
		try rawValue.withCString(encodedAs: targetEncoding, body)
	}
}
extension Symbol {
	public func uppercased() -> String {
		rawValue.uppercased()
	}
	public func lowercased() -> String {
		rawValue.lowercased()
	}
}
extension Symbol {
	public typealias UTF8View = RawValue.UTF8View
	public typealias UTF16View = RawValue.UTF16View
	public typealias UnicodeScalarView = RawValue.UnicodeScalarView
	public var utf8: UTF8View {
		_read {
			yield rawValue.utf8
		}
		_modify {
			yield &rawValue.utf8
		}
	}
	public var utf16: UTF16View {
		_read {
			yield rawValue.utf16
		}
		_modify {
			yield &rawValue.utf16
		}
	}
	public var unicodeScalars: UnicodeScalarView {
		_read {
			yield rawValue.unicodeScalars
		}
		_modify {
			yield &rawValue.unicodeScalars
		}
	}
}
extension Symbol {
	public func write<Target>(to target: inout Target) where Target : TextOutputStream {
		rawValue.write(to: &target)
	}
	public mutating func write(_ string: String) {
		rawValue.write(string)
	}
}
extension Symbol: AdditiveArithmetic {
	public static var zero: Self {
		.init(rawValue: "")
	}
	public static func+(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: lhs.rawValue + rhs.rawValue)
	}
	public static func-(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: .init(lhs.reversed().trimmingPrefix(rhs.reversed()).reversed()))
	}
}
