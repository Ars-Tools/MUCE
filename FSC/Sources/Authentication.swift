import protocol Foundation.DataProtocol
import typealias CryptoKit.SHA256
import typealias CryptoKit.HMAC
import typealias CryptoKit.SymmetricKey
extension AsyncSequence where Self: Sendable, Element == Array<UInt8> {
    /// Authenticate each element independently, appending a 32-byte HMAC-SHA256 tag.
    @inlinable
    public func signed(with key: SymmetricKey) -> some AsyncSequence<Array<UInt8>, Failure> & Sendable {
        map {
            $0 + HMAC<SHA256>.authenticationCode(for: $0, using: key)
        }
    }
    /// Return the original bytes of valid elements; silently discard invalid elements.
    @inlinable
    public func verified(with key: SymmetricKey) -> some AsyncSequence<Array<UInt8>, Failure> & Sendable {
        compactMap {
            SHA256.byteCount <= $0.count &&
            HMAC<SHA256>.isValidAuthenticationCode($0.suffix(SHA256.byteCount),
                                                   authenticating: $0.dropLast(SHA256.byteCount),
                                                   using: key) ?
                .some(.init($0.dropLast(SHA256.byteCount))) :
                .none
        }
    }
}
