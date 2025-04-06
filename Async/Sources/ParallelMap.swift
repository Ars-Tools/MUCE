//
//  ParallelMap.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
extension RandomAccessCollection where Index: Strideable, Index.Stride == Int, Self: Sendable {
	@inlinable
	public func parallelMap<R>(_ transform: (Element) -> R) -> Array<R> {
		withoutActuallyEscaping(transform) {
			let transform = unsafeBitCast($0, to: (@Sendable (Element) -> R).self)
			return.init(unsafeUninitializedCapacity: count) {
				let source = UInt(bitPattern: $0.baseAddress)
				DispatchQueue.concurrentPerform(iterations: $0.count) {
					UnsafeMutablePointer<R>(bitPattern: source)?
						.advanced(by: $0)
						.initialize(to: transform(self[startIndex.advanced(by: $0)]))
				}
				$1 = $0.count
			}
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
		let result = try parallelMap(transform) as Array<Optional<R>>
		return result.compactMap(\.self)
	}
	@inlinable
	public func parallelFlatMap<R: Sequence>(_ transform: (Element) -> R) -> Array<R.Element> {
		parallelMap(transform).flatMap(\.self)
	}
	@_disfavoredOverload
	@inlinable
	public func parallelFlatMap<R: Sequence>(_ transform: (Element) throws -> R) rethrows -> Array<R.Element> {
		let result = try parallelMap(transform) as Array<R>
		return result.flatMap(\.self)
	}
}

