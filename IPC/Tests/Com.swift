//
//  Std.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import Testing
@testable import IPC
@Suite
struct Com {
	@Test(.timeLimit(.minutes(1)))
	func pipe() async throws {
		let (r, w) = try IO.Pipe()
		async let res = r.recv(on: .none).prefix(1).map { $0.reduce(0, &+) }.reduce(0, &+)
		let req = repeatElement(.min ... .max, count: 256).map(UInt8.random(in:))
		try w.send(data: req)
		try await #expect(res == req.reduce(0, &+))
	}
}
