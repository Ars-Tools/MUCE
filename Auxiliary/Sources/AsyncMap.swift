//
//  AsyncMap.swift
//  MUCE
//
//  Created by Kota on 4/5/R7.
//
import typealias Foundation.KeyPathComparator
extension Sequence where Element: Sendable {
	@inlinable
	func dictionary<Result: Sendable, Failure: Error>(_ closure: @escaping @Sendable (Element) async throws (Failure) -> Result) async rethrows -> Dictionary<Int, Result> {
		try await withThrowingTaskGroup(of: (Int, Result).self) { queue in
			for (index, element) in enumerated() {
				queue.addTask {
					try await (index, closure(element))
				}
			}
			return try await queue.reduce(into: Dictionary<Int, Result>()) {
				$0.updateValue($1.1, forKey: $1.0)
			}
		}
	}
//	@_disfavoredOverload
	@inlinable
	public func asyncMap<Result: Sendable, Failure: Error>(_ closure: @escaping @Sendable (Element) async throws (Failure) -> Result) async rethrows -> sending Array<Result> {
		try await dictionary(closure).sorted(using: KeyPathComparator(\.key)).map(\.value)
	}
//	@_disfavoredOverload
	@inlinable
	public func asyncCompactMap<Result: Sendable, Failure: Error>(_ closure: @escaping @Sendable (Element) async throws (Failure) -> Optional<Result>) async rethrows -> sending Array<Result> {
		try await dictionary(closure).sorted(using: KeyPathComparator(\.key)).compactMap(\.value)
	}
//	@_disfavoredOverload
	@inlinable
	public func asyncFlatMap<Result: Sendable, Failure: Error>(_ closure: @escaping @Sendable (Element) async throws (Failure) -> Array<Result>) async rethrows -> sending Array<Result> {
		try await dictionary(closure).sorted(using: KeyPathComparator(\.key)).flatMap(\.value)
	}
}
