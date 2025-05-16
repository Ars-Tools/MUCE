//
//  ParallelMap.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
import Testing
import typealias Foundation.Thread
@testable import Async
@Suite
struct ParallelMap {
	@Test(.timeLimit(.minutes(1)))
	func map() {
		let source = 0..<12
		let target = source.parallelMap {
			Thread.sleep(forTimeInterval: .random(in: 6.0 ... 8.0))
			return $0 * $0
		}
		#expect(target == source.map { $0 * $0 })
	}
}
