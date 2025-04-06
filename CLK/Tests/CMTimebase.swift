//
//  CMTimebase.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import Testing
@testable import CLK
@Suite(.timeLimit(.minutes(1)))
struct CMTimebaseTests {
	@Test(.timeLimit(.minutes(1)), arguments: repeatElement((1.0 ... 4.0), count: 6).map(Float64.random(in:)).map(CMTime.init(floatLiteral:)))
	func wait(for time: CMTime) async throws {
		let clock = try CMTimebase(sourceClock: .hostTimeClock)
		try clock.set(rate: 1)
		let tic = clock.now
		try await clock.wait(until: tic + time)
		let tok = clock.now
		#expect((tok - time - tic).seconds.magnitude < 1e-1)
	}
	@Test(.timeLimit(.minutes(1)), arguments: repeatElement((1.0 ... 4.0), count: 16).map(Float64.random(in:)).map(CMTime.init(floatLiteral:)))
	func tick(each period: CMTime) async throws {
		try await confirmation(expectedCount: 7) { confirmation in
			var`catch` = Set<CMTime>()
			let clock = try CMTimebase(sourceClock: .hostTimeClock)
			let check = NotificationCenter.default.addObserver(forName: .CMTimebaseNotificationEffectiveRateChanged, object: clock, queue: .none) { notification in
				confirmation.confirm()
			}
			try clock.set(rate: 1)
			for try await now in clock.tick(every: period).prefix(3) {
				try clock.set(rate: .random(in: 0.5 ... 2.0)) // check ticker can still work even if the effective rate has been changed
				`catch`.insert(now)
				confirmation.confirm()
			}
			#expect(`catch`.count == 3)
			NotificationCenter.default.removeObserver(check)
		}
	}
}
