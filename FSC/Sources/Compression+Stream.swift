import Compression
import Auxiliary
public enum Codec: UInt32, Sendable {
    case lz4 = 0x4c5a3400
    case lzfse = 0x46534500
    case lzma = 0x4c5a4d41
    @inlinable var algorithm: compression_algorithm {
        switch self {
        case .lz4: COMPRESSION_LZ4
        case .lzfse: COMPRESSION_LZFSE
        case .lzma: COMPRESSION_LZMA
        }
    }
}

extension AsyncSequence where Self: Sendable, Element == Array<UInt8> {
    /// Each input element is an independent compression unit. No transport or key is required.
    @inlinable
    public func compressed(using codec: Codec = .lz4, capacity: Int = 1024) -> some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable {
        precondition(capacity > 0)
        return CompressionSequence(upstream: self, codec: codec, capacity: capacity)
    }
    /// Read codec and unit boundaries from compression's own records, not transport headers.
    @inlinable
    public var decompressed: some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable {
        DecompressionSequence(upstream: self)
    }
}

@usableFromInline
struct CompressionSequence<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable where Upstream.Element == Array<UInt8> {
    @usableFromInline typealias Element = Array<UInt8>
    @usableFromInline typealias Failure = any Swift.Error
    @usableFromInline let upstream: Upstream
    @usableFromInline let codec: Codec
    @usableFromInline let capacity: Int
    @usableFromInline
    init(upstream: Upstream, codec: Codec, capacity: Int) {
        self.upstream = upstream
        self.codec = codec
        self.capacity = capacity
    }
    @usableFromInline
    func makeAsyncIterator() -> Iterator {
        Iterator(base: upstream.makeAsyncIterator(), codec: codec, capacity: capacity)
    }
    @usableFromInline
    struct Iterator: AsyncIteratorProtocol {
        @usableFromInline var base: Upstream.AsyncIterator
        @usableFromInline let codec: Codec
        @usableFromInline let capacity: Int
        @usableFromInline var unit: UInt64 = 0
        @usableFromInline var chunks: Optional<AsyncStream<Array<UInt8>>.Iterator> = .none
        @inlinable
        mutating func next() async throws -> Optional<Array<UInt8>> {
            while true {
                try Task.checkCancellation()
                switch chunks {
                case .some(var iterator):
                    let result = await iterator.next()
                    chunks = .some(iterator)
                    switch result {
                    case .some(let bytes): return .some(bytes)
                    case .none: chunks = .none
                    }
                case .none:
                    break
                }
                guard case .some(let input) = try await base.next() else { return .none }
                guard unit < .max else { return .none }
                chunks = .some(compression(input, codec: codec, unit: unit, capacity: capacity).makeAsyncIterator())
                unit += 1
            }
        }
    }
}
@inlinable
func compression(_ bytes: Array<UInt8>, codec: Codec, unit: UInt64, capacity: Int) -> AsyncStream<Array<UInt8>> {
    let (stream, continuation) = AsyncStream<Array<UInt8>>.makeStream()
    let task = Task {
        defer { continuation.finish() }
        let processor: Processor
        do { processor = try Processor(mode: COMPRESSION_STREAM_ENCODE, codec: codec) }
        catch { return }
        var input = bytes[...]
        var index: UInt64 = 0
        do {
            while true {
                try Task.checkCancellation()
                let (data, ended) = try processor.process(source: &input, capacity: capacity, final: true)
                if data.isEmpty && !ended { continue }
                let record = CompressionRecord(codec: codec, unit: unit, index: index, size: bytes.count, last: ended, data: data)
                switch continuation.yield(try Auxiliary.Encoder.encode(record)) {
                case .enqueued, .dropped: break
                case .terminated: return
                @unknown default: break
                }
                index += 1
                if ended { return }
            }
        } catch { return } // Codec failures discard the unit; upstream failures propagate separately.
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
}

@usableFromInline
struct DecompressionSequence<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable where Upstream.Element == Array<UInt8> {
    @usableFromInline typealias Element = Array<UInt8>
    @usableFromInline typealias Failure = any Swift.Error
    @usableFromInline let upstream: Upstream
    @usableFromInline
    init(upstream: Upstream) {
        self.upstream = upstream
    }
    @usableFromInline
    func makeAsyncIterator() -> Iterator {
        Iterator(base: upstream.makeAsyncIterator())
    }
    @usableFromInline
    struct Iterator: AsyncIteratorProtocol {
        @usableFromInline var base: Upstream.AsyncIterator
        @usableFromInline var processor: Optional<Processor> = .none
        @usableFromInline var start: Optional<CompressionRecord> = .none
        @usableFromInline var nextIndex: UInt64 = 0
        @usableFromInline var output: Array<UInt8> = .init()
        @usableFromInline var remainder: Array<UInt8> = .init()
        @usableFromInline var ended = false
        @inlinable
        mutating func reset() {
            processor = .none
            start = .none
            output = .init()
            remainder = .init()
            ended = false
            nextIndex = 0
        }
        @inlinable
        mutating func next() async throws -> Optional<Array<UInt8>> {
            while case .some(let bytes) = try await base.next() {
                try Task.checkCancellation()
                guard case .some(let record) = (try? Auxiliary.Decoder.decode(CompressionRecord.self, from: bytes)) else {
                    reset()
                    continue
                }
                if record.index == 0 {
                    reset()
                    do { processor = .some(try Processor(mode: COMPRESSION_STREAM_DECODE, codec: record.codec)) }
                    catch { processor = .none }
                    start = .some(record)
                }
                guard case .some(let processor) = processor, case .some(let start) = start, start.unit == record.unit, start.codec == record.codec,
                      start.size == record.size, record.index == nextIndex else { reset(); continue }
                nextIndex += 1
                do {
                    var input = (remainder + record.data)[...]
                    remainder = .init()
                    if ended && !input.isEmpty { throw Error.invalid }
                    while !ended {
                        let previous = input.count
                        let (data, end) = try processor.process(source: &input, capacity: 65_536, final: record.last)
                        guard data.count <= start.size - output.count else { throw Error.invalid }
                        output += data; ended = end
                        if end || (input.isEmpty && data.count < 65_536) || (previous == input.count && data.isEmpty) { break }
                    }
                    remainder = Array(input)
                    if record.last {
                        guard ended, input.isEmpty, output.count == start.size else { throw Error.invalid }
                        let result = output; reset(); return .some(result)
                    }
                } catch { reset() }
            }
            reset(); return .none
        }
    }
}

// Compression-only format: magic(4), codec(4), unit(8), chunk(8), original size(8),
// flags(4: final), body size(4), compressed bytes. Network byte order.
@usableFromInline
struct CompressionRecord {
    @usableFromInline static let headerSize = 40
    @usableFromInline static let magic: Array<UInt8> = [0x46,0x53,0x43,0x43]
    @usableFromInline let codec: Codec
    @usableFromInline let unit: UInt64
    @usableFromInline let index: UInt64
    @usableFromInline let size: Int
    @usableFromInline let last: Bool
    @usableFromInline let data: Array<UInt8>
    @usableFromInline
    init(codec: Codec, unit: UInt64, index: UInt64, size: Int, last: Bool, data: Array<UInt8>) {
        self.codec = codec
        self.unit = unit
        self.index = index
        self.size = size
        self.last = last
        self.data = data
    }
}

extension CompressionRecord: Codable {
    @inlinable
    init(from decoder: any Swift.Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let magic = try container.decode(UInt32.self)
        let code = try container.decode(UInt32.self)
        let unit = try container.decode(UInt64.self)
        let index = try container.decode(UInt64.self)
        let size = try container.decode(UInt64.self)
        let flags = try container.decode(UInt32.self)
        let length = try container.decode(UInt32.self)
        var data = Array<UInt8>()
        for _ in 0..<length { data.append(try container.decode(UInt8.self)) }
        guard magic == 0x46534343, case .some(let codec) = Codec(rawValue: code),
              size <= 64 * 1024 * 1024, flags <= 1, Int(length) == data.count else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid compression record"))
        }
        self.init(codec: codec, unit: unit, index: index, size: Int(size), last: flags == 1, data: data)
    }
    @inlinable
    func encode(to encoder: any Swift.Encoder) throws {
        guard size >= 0, case .some(let length) = UInt32(exactly: data.count) else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid compression record"))
        }
        var container = encoder.unkeyedContainer()
        try container.encode(UInt32(0x46534343))
        try container.encode(codec.rawValue)
        try container.encode(unit)
        try container.encode(index)
        try container.encode(UInt64(size))
        let flags: UInt32 = switch last { case true: 1; case false: 0 }
        try container.encode(flags)
        try container.encode(length)
        for byte in data { try container.encode(byte) }
    }
}
@usableFromInline
enum Error: Swift.Error {
    case initialization, invalid, noProgress
}
/// A single iterator/task owns this processor; no shared mutable codec state or actor hop.
@usableFromInline
final class Processor {
    @usableFromInline
    var core: compression_stream
    @inlinable
    init(mode: compression_stream_operation, codec: Codec) throws {
        core = compression_stream(dst_ptr: .null, dst_size: 0,
                                  src_ptr: .null, src_size: 0,
                                  state: .none)
        guard compression_stream_init(&core, mode, codec.algorithm) == COMPRESSION_STATUS_OK else {
            throw Error.initialization
        }
    }
    @inlinable
    deinit {
        compression_stream_destroy(&core)
    }
    @inlinable
    func process(source: inout ArraySlice<UInt8>, capacity: Int, final: Bool) throws -> (data: Array<UInt8>, ended: Bool) {
        var consumed = 0
        var ended = false
        let data = try source.withUnsafeBufferPointer { input in
            core.src_ptr = input.baseAddress ?? .null
            core.src_size = input.count
            return try Array<UInt8>(unsafeUninitializedCapacity: capacity) { output, count in
                core.dst_ptr = output.baseAddress.unsafelyUnwrapped
                core.dst_size = output.count
                switch compression_stream_process(&core, final ? .init(COMPRESSION_STREAM_FINALIZE.rawValue) : .zero) {
                case COMPRESSION_STATUS_END:
                    ended = true
                    fallthrough
                case COMPRESSION_STATUS_OK:
                    consumed = input.count - core.src_size
                    count = output.count - core.dst_size
                case COMPRESSION_STATUS_ERROR:
                    throw Error.invalid
                default:
                    assertionFailure()
                }
                if final && !ended && consumed == 0 && count == 0 {
                    throw Error.noProgress
                }
            }
        }
        source.removeFirst(consumed)
        return (data, ended)
    }
}
