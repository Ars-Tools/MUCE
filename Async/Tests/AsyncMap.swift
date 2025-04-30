//
//  AsyncMapTests.swift
//  MUCE
//
//  Created by Kota on 4/5/R7.
//
import Testing
@testable import Async
@Suite
struct AsyncMapTests {
	@Test
	func chunk() async {
		let seq = AsyncStream { future in
			for val in 0...100 {
				future.yield(val)
			}
			future.finish()
		}
		for await seg in seq.buffer(count: 10) {
			print(seg)
		}
	}
}
