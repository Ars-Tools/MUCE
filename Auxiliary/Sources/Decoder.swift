/// Reads values in call order, without expecting field names or container metadata.
/// Records supply lengths and boundaries; only unkeyed and single-value containers are supported.
public final class Decoder: Swift.Decoder, UnkeyedDecodingContainer, SingleValueDecodingContainer {
    @inlinable@inline(__always)
    public static func decode<T: Decodable>(_ type: T.Type, from bytes: Array<UInt8>) throws -> T {
        let decoder = Decoder(bytes: bytes)
        let value = try T(from: decoder)
        guard decoder.isAtEnd else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Trailing bytes"))
        }
        return value
    }
    @usableFromInline
    var bytes: ArraySlice<UInt8>
    public var currentIndex = 0
    @inlinable
    public var count: Optional<Int> { .none }
    @inlinable
    public var isAtEnd: Bool { bytes.isEmpty }
    public let codingPath: Array<any CodingKey> = .init()
    public let userInfo: Dictionary<CodingUserInfoKey, Any> = .init()
    @inlinable
    public init(bytes: Array<UInt8>) { self.bytes = bytes[...] }
    @inlinable
    public func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { throw unsupported(Dictionary<String, UInt8>.self) }
    @inlinable
    public func unkeyedContainer() -> any UnkeyedDecodingContainer { self }
    @inlinable
    public func singleValueContainer() -> any SingleValueDecodingContainer { self }
    @inlinable
    public func nestedContainer<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { throw unsupported(Dictionary<String, UInt8>.self) }
    @inlinable
    public func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer { self }
    @inlinable
    public func superDecoder() throws -> any Swift.Decoder { self }
    @inlinable
    public func unsupported<T>(_ type: T.Type) -> DecodingError {
        .typeMismatch(type, .init(codingPath: codingPath, debugDescription: "Unsupported fixed-layout wire value"))
    }
    @inlinable@inline(__always)
    func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let width = MemoryLayout<T>.size
        guard width <= bytes.count else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Truncated wire value"))
        }
        let value = bytes.prefix(width).reduce(T.zero) { ($0 << 8) | T(truncatingIfNeeded: $1) }
        bytes.removeFirst(width)
        currentIndex += 1
        return value
    }
    @inlinable
    public func decodeNil() -> Bool {
        false
    }
    @inlinable
    public func decode(_ type: Bool.Type) throws -> Bool {
        switch try read(UInt8.self) {
        case 0: false
        case 1: true
        default: throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Invalid wire boolean"))
        }
    }
    @inlinable
    public func decode(_ type: String.Type) throws -> String { throw unsupported(type) }
    @inlinable
    public func decode(_ type: Double.Type) throws -> Double { Double(bitPattern: try read(UInt64.self)) }
    @inlinable
    public func decode(_ type: Float.Type) throws -> Float { Float(bitPattern: try read(UInt32.self)) }
    @inlinable
    public func decode(_ type: Int.Type) throws -> Int { Int(try read(Int64.self)) }
    @inlinable
    public func decode(_ type: Int8.Type) throws -> Int8 { try read(type) }
    @inlinable
    public func decode(_ type: Int16.Type) throws -> Int16 { try read(type) }
    @inlinable
    public func decode(_ type: Int32.Type) throws -> Int32 { try read(type) }
    @inlinable
    public func decode(_ type: Int64.Type) throws -> Int64 { try read(type) }
    @inlinable
    public func decode(_ type: UInt.Type) throws -> UInt { UInt(try read(UInt64.self)) }
    @inlinable
    public func decode(_ type: UInt8.Type) throws -> UInt8 { try read(type) }
    @inlinable
    public func decode(_ type: UInt16.Type) throws -> UInt16 { try read(type) }
    @inlinable
    public func decode(_ type: UInt32.Type) throws -> UInt32 { try read(type) }
    @inlinable
    public func decode(_ type: UInt64.Type) throws -> UInt64 { try read(type) }
    @inlinable
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: self)
    }
}
