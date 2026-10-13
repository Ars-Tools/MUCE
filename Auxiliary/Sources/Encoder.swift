/// Serializes values in call order, without adding field names or container metadata.
/// Records supply lengths and boundaries; only unkeyed and single-value containers are supported.
public final class Encoder: Swift.Encoder, UnkeyedEncodingContainer, SingleValueEncodingContainer {
    @inlinable@inline(__always)
    public static func encode<T: Encodable>(_ value: T) throws -> Array<UInt8> {
        let encoder = Encoder()
        try value.encode(to: encoder)
        return encoder.bytes
    }
    @inlinable
    init() {}
    @usableFromInline
    var bytes: Array<UInt8> = .init()
    public var count = 0
    public let codingPath: Array<any CodingKey> = .init()
    public let userInfo: Dictionary<CodingUserInfoKey, Any> = .init()
    @inlinable
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        preconditionFailure("Sequential encoding requires an unkeyed or single-value container")
    }
    @inlinable
    public func unkeyedContainer() -> any UnkeyedEncodingContainer { self }
    @inlinable
    public func singleValueContainer() -> any SingleValueEncodingContainer { self }
    @inlinable
    public func nestedContainer<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        preconditionFailure("Nested wire containers are unsupported")
    }
    @inlinable
    public func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer { self }
    @inlinable
    public func superEncoder() -> any Swift.Encoder { self }
    @inlinable@inline(__always)
    public func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.bigEndian) { bytes.append(contentsOf: $0) }
        count += 1
    }
    @inlinable
    public func unsupported<T>(_ value: T) -> EncodingError {
        .invalidValue(value, .init(codingPath: codingPath, debugDescription: "Unsupported fixed-layout wire value"))
    }
    @inlinable
    public func encodeNil() throws { throw unsupported(Optional<UInt8>.none) }
    @inlinable
    public func encode(_ value: Bool) {
        append(value ? 1 as UInt8 : 0 as UInt8)
    }
    @inlinable
    public func encode(_ value: String) throws { throw unsupported(value) }
    @inlinable
    public func encode(_ value: Double) { append(value.bitPattern) }
    @inlinable
    public func encode(_ value: Float) { append(value.bitPattern) }
    @inlinable
    public func encode(_ value: Int) { append(Int64(value)) }
    @inlinable
    public func encode(_ value: Int8) { append(value) }
    @inlinable
    public func encode(_ value: Int16) { append(value) }
    @inlinable
    public func encode(_ value: Int32) { append(value) }
    @inlinable
    public func encode(_ value: Int64) { append(value) }
    @inlinable
    public func encode(_ value: UInt) { append(UInt64(value)) }
    @inlinable
    public func encode(_ value: UInt8) { append(value) }
    @inlinable
    public func encode(_ value: UInt16) { append(value) }
    @inlinable
    public func encode(_ value: UInt32) { append(value) }
    @inlinable
    public func encode(_ value: UInt64) { append(value) }
    @inlinable
    public func encode<T: Encodable>(_ value: T) throws {
        try value.encode(to: self)
    }
}

