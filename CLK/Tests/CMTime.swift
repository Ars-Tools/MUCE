//
//  CMTime.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import Testing
import Darwin
@testable import CLK
@Suite
struct CMTimeTests {
	@Test(arguments: [
		(CMTime.zero, Float64.zero),
		(CMTime.indefinite, Float64.nan),
		(CMTime.positiveInfinity,  Float64.infinity),
		(CMTime.negativeInfinity, -Float64.infinity),
		(CMTime(value: 5, timescale: 4), 1.25 as Float64),
		(CMTime(value: 3, timescale: 2), 1.50 as Float64),
		(CMTime(value: 10, timescale: 4), 2.50 as Float64),
		(CMTime(value: 38, timescale: 10), 3.80 as Float64),
	])
	func parse(target: CMTime, source: Float64) {
		#expect(target == .init(floatLiteral: source))
	}
	@Test(arguments: [
		(CMTime(value:  4, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .roundTowardNegativeInfinity),
		(CMTime(value: -6, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .roundTowardNegativeInfinity),
		(CMTime(value:  6, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .roundTowardPositiveInfinity),
		(CMTime(value: -4, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .roundTowardPositiveInfinity),
	] as Array<(CMTime, Float64, CMTime, CMTimeRoundingMethod)>)
	func quantDirection(target: CMTime, source: Float64, resolution: CMTime, algorithm: CMTimeRoundingMethod) {
		#expect(target == CMTime(floatLiteral: source).quantise(by: resolution, rounding: algorithm))
	}
	@Test(arguments: [
		(CMTime(value:  4, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .roundTowardZero),
		(CMTime(value: -4, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .roundTowardZero),
		(CMTime(value:  6, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .roundAwayFromZero),
		(CMTime(value: -6, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .roundAwayFromZero),
	] as Array<(CMTime, Float64, CMTime, CMTimeRoundingMethod)>)
	func quantZero(target: CMTime, source: Float64, resolution: CMTime, algorithm: CMTimeRoundingMethod) {
		#expect(target == CMTime(floatLiteral: source).quantise(by: resolution, rounding: algorithm))
	}
	@Test(arguments: [
		(CMTime(value:  4, timescale: 5),  0.9, CMTime(value: 2, timescale: 5), .roundHalfAwayFromZero),
		(CMTime(value:  6, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .roundHalfAwayFromZero),
		(CMTime(value: -4, timescale: 5), -0.9, CMTime(value: 2, timescale: 5), .roundHalfAwayFromZero),
		(CMTime(value: -6, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .roundHalfAwayFromZero),
//		(CMTime(value:  4, timescale: 5),  0.9, CMTime(value: 2, timescale: 5), .quickTime),
//		(CMTime(value:  6, timescale: 5),  1.1, CMTime(value: 2, timescale: 5), .quickTime),
//		(CMTime(value: -4, timescale: 5), -0.9, CMTime(value: 2, timescale: 5), .quickTime),
//		(CMTime(value: -6, timescale: 5), -1.1, CMTime(value: 2, timescale: 5), .quickTime),
	] as Array<(CMTime, Float64, CMTime, CMTimeRoundingMethod)>)
	func quantDefault(target: CMTime, source: Float64, resolution: CMTime, algorithm: CMTimeRoundingMethod) {
		#expect(target == CMTime(floatLiteral: source).quantise(by: resolution, rounding: algorithm))
	}
}
