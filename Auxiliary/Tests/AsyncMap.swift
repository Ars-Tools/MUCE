//
//  AsyncMapTests.swift
//  MUCE
//
//  Created by Kota on 4/5/R7.
//
import Testing
@testable import Auxiliary
@Suite
struct AsyncMapTests {
	@Test(.timeLimit(.minutes(1)))
	func map() async throws {
		let source = 0..<12
		let target = try await source.asyncMap {
			try await Task.sleep(for: .milliseconds(.random(in: 6000...8000)))
			return $0 * $0
		}
		#expect(target == source.map { $0 * $0 })
	}
}
