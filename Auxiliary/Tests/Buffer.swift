//
//  Buffer.swift
//  MUCE
//
//  Created by Kota on 5/17/R7.
//
import Testing
import typealias Foundation.ProcessInfo
import typealias Foundation.FileManager
@testable import Auxiliary
@Suite
struct BufferTests {
	@Test
	func mmap() throws {
		let value = Int.random(in: .min ... .max)
		let info = ProcessInfo.processInfo
		let path = "/tmp/\(info.processName)-\(info.processIdentifier)-\(#function)"
		do {
			try Buffer<Int>(at: path, least: 32)[0] = value
		}
		do {
			let restore = try Buffer<Int>(at: path)
			#expect(restore.count == 32)
			#expect(restore.first == value)
		}
		try FileManager.default.removeItem(atPath: path)
	}
}
