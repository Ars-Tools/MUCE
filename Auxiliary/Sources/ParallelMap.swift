//
//  ParallelMap.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
extension RandomAccessCollection where Index: Strideable, Index.Stride == Int {
	@inlinable
	public func parallelMap<R>(_ transform: (Element) -> R) -> Array<R> {
		.init(unsafeUninitializedCapacity: count) {
			guard let memory = $0.baseAddress else { return }
			withoutActuallyEscaping(transform) { transform in
				DispatchQueue.concurrentPerform(iterations: count, execute: unsafeBitCast({
					memory.advanced(by: $0).initialize(to: transform(self[startIndex.advanced(by: $0)]))
				}, to: (@Sendable(Int)->Void).self))
			}
			$1 = $0.count
		}
	}
	@_disfavoredOverload
	@inlinable
	public func parallelMap<R>(_ transform: (Element) throws -> R) rethrows -> Array<R> {
		try parallelMap { value in
			Result<R, Swift.Error> {
				try transform(value)
			}
		}.map{try $0.get()}
	}
	@inlinable
	public func parallelCompactMap<R>(_ transform: (Element) -> Optional<R>) -> Array<R> {
		parallelMap(transform).compactMap(\.self)
	}
	@_disfavoredOverload
	@inlinable
	public func parallelCompactMap<R>(_ transform: (Element) throws -> Optional<R>) rethrows -> Array<R> {
		try parallelMap(transform).compactMap(\.self)
	}
	@inlinable
	public func parallelFlatMap<R>(_ transform: (Element) -> some Sequence<R>) -> Array<R> {
		parallelMap(transform).flatMap(\.self)
	}
	@_disfavoredOverload
	@inlinable
	public func parallelFlatMap<R>(_ transform: (Element) throws -> some Sequence<R>) rethrows -> Array<R> {
		try parallelMap(transform).flatMap(\.self)
	}
}

