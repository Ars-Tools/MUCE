//
//  Concurrency+.swift
//  MUCE
//
//  Created by Kota on 10/6/26.
//
import typealias Synchronization.Atomic
extension AsyncSequence {
    @inlinable@_transparent@inline(__always)
    public var enumerated: some AsyncSequence<(Int, Element), Failure> {
        let counter = Atomic<Int>(0)
        return map {
            (counter.wrappingAdd(1, ordering: .acquiringAndReleasing).oldValue, $0)
        }
    }
}
@usableFromInline
final class SharedSequence<Upstream: AsyncSequence & Sendable>: Sendable where Upstream.Element: Sendable, Upstream.Failure == Never {
    @usableFromInline
    final actor Continuous {
        @usableFromInline
        var continuous: Dictionary<Int, AsyncStream<Upstream.Element>.Continuation>
        @inlinable
        init() {
            continuous = .init()
        }
    }
    @usableFromInline
    let continuous: Continuous
    @usableFromInline
    let task: Task<Void, any Swift.Error>
    @inlinable
    init(upstream: Upstream) {
        continuous = Continuous()
        task = .init { [continuous] in
            for try await element in upstream {
                for closure in await continuous.continuous.values {
                    closure.yield(element)
                }
            }
            for closure in await continuous.continuous.values {
                closure.finish()
            }
        }
    }
}
extension SharedSequence.Continuous {
    @inlinable
    func append(closure: AsyncStream<Upstream.Element>.Continuation) {
        continuous.updateValue(closure, forKey: closure.hashValue)
    }
    @inlinable
    func remove(closure: AsyncStream<Upstream.Element>.Continuation.Termination) {
        continuous.removeValue(forKey: closure.hashValue)
    }
}
extension SharedSequence: AsyncSequence {
    @usableFromInline
    typealias Element = Upstream.Element
    @inlinable
    func makeAsyncIterator() -> AsyncStream<Upstream.Element>.AsyncIterator {
        let (s, a) = AsyncStream<Upstream.Element>.makeStream(bufferingPolicy: .bufferingNewest(1))
        Task {
            await continuous.append(closure: a)
        }
        a.onTermination = { [continuous] a in
            Task {
                await continuous.remove(closure: a)
            }
        }
        return s.makeAsyncIterator()
    }
}
extension AsyncSequence where Self: Sendable, Element: Sendable, Failure == Never {
    @inlinable@_transparent@inline(__always)
    public var shared: some AsyncSequence<Element, Failure> {
        SharedSequence(upstream: self)
    }
}
