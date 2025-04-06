//
//  Codable.swift
//  MUCE
//
//  Created by Kota on 3/31/R7.
//
import Testing
@testable import OSC
@Suite
struct Codable {
	func eq(_ lhs: some Collection<Argument>, _ rhs: some Collection<Argument>) -> Bool {
		lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
			switch ($0, $1) {
			case (let l as Int32, let r as Int32):
				l == r
			case (let l as Float32, let r as Float32):
				l == r
			case (let l as String, let r as String):
				l == r
			case (let l as Blob, let r as Blob):
				l == r
			case (let l as Int64, let r as Int64):
				l == r
			case (let l as Float64, let r as Float64):
				l == r
			case (let l as Symbol, let r as Symbol):
				l == r
			case (let l as Character, let r as Character):
				l == r
			case (let l as MIDIMessage, let r as MIDIMessage):
				l == r
			case (let l as Color, let r as Color):
				l == r
			case (let l as TimeTag, let r as TimeTag):
				l == r
			case (let l as Bool, let r as Bool):
				l == r
			case (is Impulse, is Impulse):
				true
			case (is Nil, is Nil):
				true
			case (let l as Array<Argument>, let r as Array<Argument>):
				eq(l, r)
			default:
				false
			}
		}
	}
	@Test
	func bundle() {
		let bundle = Packet.Bundle(timestamp: 10000, packets: [
			.Message(address: "/1", arguments: [1] as [Int32]),
			.Message(address: "/12", arguments: [1, 2] as [Int32]),
			.Message(address: "/123", arguments: [1, 2, 3] as [Int32]),
			.Message(address: "/midi", arguments: [Color(.yellow)]),
			.Bundle(timestamp: 20000, packets: [
				.Message(address: "/a/b", arguments: [1] as [Int32]),
				.Message(address: "/a/b/c", arguments: [1] as [Int32]),
			]),
			.Message(address: "/1234", arguments: [1, [2, ["3", 4, "XY" as Symbol]]]),
		])
		switch Packet(decode: bundle.encode() as Array<UInt8>) {
		case.some(let decode):
			for ((a, b, c), (x, y, z)) in zip(bundle, decode) {
				guard a == x, eq(b, y), c == z else {
					Issue.record()
					continue
				}
			}
			break
		case.none:
			Issue.record()
		}
	}
}
