//
//  RTP.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
import Testing
@testable import RTP
@Suite
struct PacketTests {
	let range = UInt8.min ... UInt8.max
	@Test(arguments: [1,2,3,4,5,6,7,8])
	func codable(count: Int) throws {
		let raw = Packet(
			source: .random(in: .min ... .max),
			contributions: [],
			sequence: .random(in: .min ... .max),
			timestamp: .random(in: .min ... .max),
			type: .PCMA,
			payload: repeatElement(UInt8.min...UInt8.max, count: count).map(UInt8.random(in:))
		)
		let enc = raw.encode()
		let dec = try Packet(from: enc)
		#expect(raw == dec)
	}
	@Test(arguments: [
		(1,1),(1,2),(1,3),(1,4),
		(2,1),(2,2),(2,3),(2,4),
		(3,1),(3,2),(3,3),(3,4),
		(4,1),(4,2),(4,3),(4,4),
	])
	func codable(extension: Int, payload: Int) throws {
		let raw = Packet(
			source: .random(in: .min ... .max),
			contributions: [],
			sequence: .random(in: .min ... .max),
			timestamp: .random(in: .min ... .max),
			type: .PCMA,
			payload: repeatElement(range, count: payload).map(UInt8.random(in:)),
			extension: .init(profile: .random(in: .min ... .max), payload: repeatElement(range, count: `extension`).map(UInt8.random(in:)))
		)
		let enc = raw.encode()
		let dec = try Packet(from: enc)
		#expect(raw == dec)
	}
}
