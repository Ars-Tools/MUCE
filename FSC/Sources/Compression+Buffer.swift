//
//  Compression+Buffer.swift
//  MUCE
//
//  Created by Kota on 10/13/26.
//
import typealias Compression.Algorithm
import func Compression.compression_encode_scratch_buffer_size
import func Compression.compression_decode_scratch_buffer_size
import func Compression.compression_encode_buffer
import func Compression.compression_decode_buffer
extension Algorithm: @unchecked @retroactive Sendable {
    @inlinable
    var encodeWorkspace: Int {
        compression_encode_scratch_buffer_size(rawValue)
    }
    @inlinable
    var decodeWorkspace: Int {
        compression_decode_scratch_buffer_size(rawValue)
    }
}
extension AsyncSequence where Self: Sendable, Element == Array<UInt8>, Failure == Never {
    @inlinable
    public func compressed(using codec: Algorithm) -> some AsyncSequence<Element, Failure> & Sendable {
        compactMap { data in
            let pack = data.isEmpty ? Array<UInt8>() : .init(unsafeUninitializedCapacity: MemoryLayout<UInt32>.stride + MemoryLayout<UInt32>.stride + data.count + codec.encodeWorkspace) {
                let head = UnsafeMutableBufferPointer(rebasing: $0.prefix(MemoryLayout<UInt32>.stride + MemoryLayout<UInt32>.stride))
                let body = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(head.count).prefix(data.count))
                let tail = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(head.count).dropFirst(body.count))
                _ = withUnsafeBytes(of: codec.rawValue.rawValue.bigEndian, head.prefix(MemoryLayout<UInt32>.stride).initialize(fromContentsOf:))
                _ = withUnsafeBytes(of: UInt32(data.count).bigEndian, head.suffix(MemoryLayout<UInt32>.stride).initialize(fromContentsOf:))
                $1 = switch compression_encode_buffer(body.baseAddress.unsafelyUnwrapped,
                                                      body.count,
                                                      data,
                                                      data.count,
                                                      tail.baseAddress,
                                                      codec.rawValue) {
                case 0:
                    0
                case let size:
                    size + head.count
                }
            }
            return pack.isEmpty ? .none : .some(pack)
        }
    }
    @inlinable
    public var decompressed: some AsyncSequence<Element, Failure> {
        compactMap {
            let head = $0.prefix(MemoryLayout<UInt32>.stride + MemoryLayout<UInt32>.stride)
            let mode = head.prefix(MemoryLayout<UInt32>.stride).reduce(0 as UInt32) { ($0 << 8) | .init($1) }
            let size = head.suffix(MemoryLayout<UInt32>.stride).reduce(0 as UInt32) { ($0 << 8) | .init($1) }
            let body = $0.dropFirst(head.count)
            let data = if !body.isEmpty, case.some(let codec) = Algorithm(rawValue: .init(rawValue: mode)) {
                body.withUnsafeBufferPointer { data in
                    Array<UInt8>(unsafeUninitializedCapacity: .init(size) + codec.decodeWorkspace) {
                        let body = UnsafeMutableBufferPointer(rebasing: $0.prefix(.init(size)))
                        let tail = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(body.count))
                        $1 = compression_decode_buffer(body.baseAddress.unsafelyUnwrapped,
                                                       body.count,
                                                       data.baseAddress.unsafelyUnwrapped,
                                                       data.count,
                                                       tail.baseAddress,
                                                       codec.rawValue) == .init(size) ? .init(size) : 0
                    }
                }
            } else {
                Array<UInt8>()
            }
            return data.isEmpty ? .none : .some(data)
        }
    }
}
