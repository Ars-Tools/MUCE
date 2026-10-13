import Auxiliary
import func Darwin.arc4random_buf
extension AsyncSequence where Self: Sendable, Element == Array<UInt8> {
    /// Pack opaque input elements; never inspect compression or authentication formats.
    public var packed: some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable { packed(capacity: 1104) }
    public func packed(capacity: Int) -> some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable {
        precondition(capacity > 0)
        return PackingSequence(upstream: self, capacity: capacity)
    }
    /// Restore opaque elements. Missing units are skipped after a short reordering window.
    /// For network input, authenticate before ordering; ordering itself does not verify MACs.
    public var ordered: some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable { ordered(wait: .milliseconds(20)) }
    public func ordered(wait: Duration) -> some AsyncSequence<Array<UInt8>, any Swift.Error> & Sendable {
        precondition(wait > .zero)
        return OrderingSequence(upstream: self, wait: wait)
    }
}

@usableFromInline
struct PackingSequence<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable where Upstream.Element == Array<UInt8> {
    @usableFromInline typealias Element = Array<UInt8>
    @usableFromInline typealias Failure = any Swift.Error
    @usableFromInline let upstream: Upstream
    @usableFromInline let capacity: Int
    @usableFromInline
    func makeAsyncIterator() -> Iterator {
        Iterator(base: upstream.makeAsyncIterator(), capacity: capacity, session: .init(unsafeUninitializedCapacity: 16) {
            $1 = $0.count
            arc4random_buf($0.baseAddress, $0.count)
        })
    }
    @usableFromInline
    struct Iterator: AsyncIteratorProtocol {
        @usableFromInline var base: Upstream.AsyncIterator
        @usableFromInline let capacity: Int
        @usableFromInline let session: Array<UInt8>
        @usableFromInline var nextUnit: UInt64 = 0
        @usableFromInline var input: Optional<Array<UInt8>> = .none
        @usableFromInline var offset = 0
        @usableFromInline var index: UInt32 = 0
        @usableFromInline
        mutating func next() async throws -> Optional<Array<UInt8>> {
            try Task.checkCancellation()
            switch input {
            case .none:
                guard case .some(let bytes) = try await base.next(), nextUnit < .max else { return .none }
                input = .some(bytes); offset = 0; index = 0
            case .some:
                break
            }
            let bytes = input.unsafelyUnwrapped
            let count = Swift.min(capacity, bytes.count - offset)
            let last = offset + count == bytes.count
            let packet = try Auxiliary.Encoder.encode(OrderRecord(session: session,
                                     unit: nextUnit,
                                     size: bytes.count,
                                     index: index,
                                     last: last,
                                     data: Array(bytes.dropFirst(offset).prefix(count))
            ))
            offset += count
            index += 1
            if last {
                input = .none
                nextUnit += 1
            }
            return .some(packet)
        }
    }
}
@usableFromInline
struct OrderingSequence<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable where Upstream.Element == Array<UInt8> {
    @usableFromInline typealias Element = Array<UInt8>
    @usableFromInline typealias Failure = any Swift.Error
    @usableFromInline let upstream: Upstream
    @usableFromInline let wait: Duration
    @inlinable
    func makeAsyncIterator() -> AsyncThrowingStream<Element, any Swift.Error>.Iterator {
        let (stream, continuation) = AsyncThrowingStream<Element, any Swift.Error>.makeStream()
        let receiver = Receiver(continuation: continuation, wait: wait)
        let task = Task {
            do {
                for try await packet in upstream {
                    try Task.checkCancellation()
                    await receiver.accept(packet)
                }
                await receiver.finish()
            } catch { await receiver.finish(error: error) }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream.makeAsyncIterator()
    }
}

/// All reassembly and gap deadlines belong to this layer, one receiver per sending source.
@usableFromInline
actor Receiver {
    @usableFromInline let continuation: AsyncThrowingStream<Array<UInt8>, any Swift.Error>.Continuation
    @usableFromInline let wait: Duration
    @usableFromInline var session: Optional<Array<UInt8>> = .none
    @usableFromInline var retired: Set<Array<UInt8>> = .init()
    @usableFromInline var next: UInt64 = 0
    @usableFromInline var units: Dictionary<UInt64, Unit> = .init()
    @usableFromInline var ready: Dictionary<UInt64, Array<UInt8>> = .init()
    @usableFromInline var bufferedBytes = 0
    @usableFromInline var timer: Optional<Task<Void, Never>> = .none
    @usableFromInline var generation: UInt64 = 0
    @usableFromInline var closed = false
    @inlinable
    init(continuation: AsyncThrowingStream<Array<UInt8>, any Swift.Error>.Continuation, wait: Duration) {
        self.continuation = continuation; self.wait = wait
    }
    @usableFromInline
    struct Unit {
        @usableFromInline let size: Int
        @usableFromInline var final: Optional<UInt32> = .none
        @usableFromInline var chunks: Dictionary<UInt32, Array<UInt8>> = .init()
        @usableFromInline var bytes = 0
    }
    @usableFromInline
    func accept(_ bytes: Array<UInt8>) {
        guard !closed, case .some(let record) = (try? Auxiliary.Decoder.decode(OrderRecord.self, from: bytes)), !retired.contains(record.session) else { return }
        if session != .some(record.session) {
            switch session {
            case .some(let previous): retired.insert(previous)
            case .none: break
            }
            session = .some(record.session); next = 0; units = .init(); ready = .init(); bufferedBytes = 0
            cancelTimer()
        }
        guard record.unit >= next, ready[record.unit] == .none,
              bufferedBytes <= 64 * 1024 * 1024 - record.data.count else { return }
        var unit = switch units[record.unit] {
        case .some(let existing): existing
        case .none: Unit(size: record.size)
        }
        guard unit.size == record.size, unit.chunks[record.index] == .none,
              unit.bytes <= unit.size - record.data.count else { return }
        if case .some(let final) = unit.final, record.index > final { return }
        if record.last {
            guard unit.final == .none || unit.final == .some(record.index),
                  !unit.chunks.keys.contains(where: { $0 > record.index }) else { return }
            unit.final = .some(record.index)
        }
        unit.chunks[record.index] = .some(record.data)
        unit.bytes += record.data.count; bufferedBytes += record.data.count
        if case .some(let final) = unit.final, unit.chunks.count == Int(final) + 1, unit.bytes == unit.size {
            var output: Array<UInt8> = .init(); output.reserveCapacity(unit.size)
            for index in 0...final { output += unit.chunks[index].unsafelyUnwrapped }
            units.removeValue(forKey: record.unit); ready[record.unit] = .some(output)
        } else { units[record.unit] = .some(unit) }
        drain()
        schedule()
    }
    @inlinable
    func drain() {
        while case .some(let bytes) = ready.removeValue(forKey: next) {
            bufferedBytes -= bytes.count
            next += 1
            switch continuation.yield(bytes) {
            case .enqueued, .dropped: break
            case .terminated: closed = true; clear(); return
            @unknown default: break
            }
        }
        if ready.isEmpty { cancelTimer() }
    }
    @inlinable
    func schedule() {
        guard !closed, !ready.isEmpty, case .none = timer else { return }
        generation &+= 1
        let token = generation
        timer = .some(Task {
            do { try await Task.sleep(for: wait) } catch { return }
            skipGap(token: token)
        })
    }
    @inlinable
    func skipGap(token: UInt64) {
        guard !closed, generation == token, case .some(let first) = ready.keys.min() else { return }
        timer = .none
        advance(to: first); drain(); schedule()
    }
    @inlinable
    func advance(to index: UInt64) {
        for key in units.keys.filter({ $0 < index }) {
            bufferedBytes -= units.removeValue(forKey: key).unsafelyUnwrapped.bytes
        }
        next = index
    }
    @inlinable
    func cancelTimer() {
        generation &+= 1
        switch timer {
        case .some(let task): task.cancel()
        case .none: break
        }
        timer = .none
    }
    @inlinable
    func clear() {
        cancelTimer()
        units = .init()
        ready = .init()
        bufferedBytes = 0
    }
    @inlinable
    func finish(error: Optional<any Swift.Error> = .none) {
        guard !closed else { return }
        cancelTimer()
        while case .some(let first) = ready.keys.min() { advance(to: first); drain() }
        closed = true; clear(); continuation.finish(throwing: error)
    }
}

// Ordering-only format: magic(4), session(16), unit(8), original size(8), chunk(4),
// flags(4: final), body size(4), opaque bytes. No codec or media fields.
@usableFromInline
struct OrderRecord: Sendable {
    @usableFromInline static let headerSize = 48
    @usableFromInline static let magic: Array<UInt8> = [0x46,0x53,0x43,0x4f]
    @usableFromInline let session: Array<UInt8>
    @usableFromInline let unit: UInt64
    @usableFromInline let size: Int
    @usableFromInline let index: UInt32
    @usableFromInline let last: Bool
    @usableFromInline let data: Array<UInt8>
}

extension OrderRecord: Codable {
    @inlinable
    init(from decoder: any Swift.Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let magic = try container.decode(UInt32.self)
        var session = Array<UInt8>(); session.reserveCapacity(16)
        for _ in 0..<16 { session.append(try container.decode(UInt8.self)) }
        let unit = try container.decode(UInt64.self)
        let size = try container.decode(UInt64.self)
        let index = try container.decode(UInt32.self)
        let flags = try container.decode(UInt32.self)
        let length = try container.decode(UInt32.self)
        var data = Array<UInt8>()
        for _ in 0..<length { data.append(try container.decode(UInt8.self)) }
        guard magic == 0x4653434f, size <= 64 * 1024 * 1024, index < 131_072, flags <= 1,
              Int(length) == data.count, length > 0 || (size == 0 && index == 0 && flags == 1) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid ordering record"))
        }
        self.session = session; self.unit = unit; self.size = Int(size)
        self.index = index; self.last = flags == 1; self.data = data
    }
    @inlinable
    func encode(to encoder: any Swift.Encoder) throws {
        guard session.count == 16, size >= 0, case .some(let length) = UInt32(exactly: data.count) else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Invalid ordering record"))
        }
        var container = encoder.unkeyedContainer()
        try container.encode(UInt32(0x4653434f))
        for byte in session { try container.encode(byte) }
        try container.encode(unit)
        try container.encode(UInt64(size))
        try container.encode(index)
        let flags: UInt32 = switch last { case true: 1; case false: 0 }
        try container.encode(flags)
        try container.encode(length)
        for byte in data { try container.encode(byte) }
    }
}
