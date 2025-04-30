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
	@Test(arguments: 1...4)
	func codable(count: Int) throws {
		let raw = RTP.Packet(
			source: .random(in: .min ... .max),
			contributions: repeatElement(UInt32.min ... UInt32.max, count: 8).map(UInt32.random(in:)),
			sequence: .random(in: .min ... .max),
			timestamp: .random(in: .min ... .max),
			type: .init(rawValue: 96),
			payload: repeatElement(range, count: count).map(UInt8.random(in:))
		)
		let enc = raw.encode()
		let dec = try RTP.Packet(from: enc)
		#expect((
			raw.timestamp,
			raw.synchronization,
			raw.contributions,
			raw.sequence,
			raw.timestamp,
			raw.type.rawValue
		) == (
			dec.timestamp,
			dec.synchronization,
			dec.contributions,
			dec.sequence,
			dec.timestamp,
			dec.type.rawValue
		))
		#expect(raw.extensions == dec.extensions)
		#expect(raw.payload == dec.payload)
	}
	static var cases: Array<(Int, Int)> {
		(1...5).flatMap { x in (1...5).map { (x, $0) } }
	}
	@Test(arguments: cases)
	func codable(extension: Int, payload: Int) throws {
		let raw = RTP.Packet(
			source: .random(in: .min ... .max),
			contributions: repeatElement(UInt32.min ... UInt32.max, count: 8).map(UInt32.random(in:)),
			sequence: .random(in: .min ... .max),
			timestamp: .random(in: .min ... .max),
			type: .init(rawValue: 96),
			payload: repeatElement(range, count: payload).map(UInt8.random(in:)),
			extension: .init(profile: .random(in: .min ... .max), payload: repeatElement(range, count: `extension`).map(UInt8.random(in:)))
		)
		let enc = raw.encode()
		let dec = try RTP.Packet(from: enc)
		#expect((
			raw.timestamp,
			raw.synchronization,
			raw.contributions,
			raw.sequence,
			raw.timestamp,
			raw.type.rawValue
		) == (
			dec.timestamp,
			dec.synchronization,
			dec.contributions,
			dec.sequence,
			dec.timestamp,
			dec.type.rawValue
		))
		#expect(raw.extensions == dec.extensions)
		#expect(raw.payload == dec.payload)
	}
}
