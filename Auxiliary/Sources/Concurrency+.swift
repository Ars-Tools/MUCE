//
//  Concurrency+.swift
//  MUCE
//
//  Created by Kota on 10/6/26.
//
import typealias Synchronization.Atomic
extension AsyncSequence {
    @inlinable@inline(__always)@_transparent
    public var enumerated: some AsyncSequence<(Int, Element), Failure> {
        let counter = Atomic<Int>(0)
        return map {
            (counter.wrappingAdd(1, ordering: .acquiringAndReleasing).oldValue, $0)
        }
    }
}
@usableFromInline
actor Pipe {
    
}
@usableFromInline
actor SharedSequence<Upstream: AsyncSequence & Sendable>: Sendable where Upstream.Element: Sendable, Upstream.Failure == Never {
    @usableFromInline
    let upstream: Upstream
    @inlinable
    init(upstream: Upstream) {
        self.upstream = upstream
        
    }
    deinit {
        
    }
}
extension SharedSequence: @preconcurrency AsyncSequence {
    @usableFromInline
    typealias Element = Upstream.Element
    @inlinable
    func makeAsyncIterator() -> AsyncStream<Upstream.Element>.AsyncIterator {
        let (s, a) = AsyncStream<Upstream.Element>.makeStream()
        a.onTermination = { _ in
            
        }
        return s.makeAsyncIterator()
    }
}
