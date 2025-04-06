//
//  CMTimebase+.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
@_exported @preconcurrency public import typealias CoreMedia.CMTimebase
@preconcurrency import func CoreMedia.CMTimeAdd
@preconcurrency import func CoreMedia.CMTimeAbsoluteValue
@preconcurrency import func CoreMedia.CMTimeCompare
@preconcurrency import let CoreMedia.kCMTimebaseNotification_TimeJumped
@preconcurrency import let CoreMedia.kCMTimebaseNotification_EffectiveRateChanged
@preconcurrency import let CoreMedia.kCMTimebaseNotificationKey_EventTime
@preconcurrency import typealias CoreMedia.CMTime
@preconcurrency import typealias CoreMedia.CMTimeValue
@preconcurrency import typealias CoreMedia.CMTimeScale
@preconcurrency import typealias CoreMedia.NotificationCenter
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias Dispatch.DispatchSource
extension CMTimebase {
	@inlinable
	func convert(reference time: CMTime) -> CMTime {
		source.convertTime(time, to: self)
	}
}
extension CMTimebase: Synchronisable {
	@inline(__always)
	@inlinable
	public var sign: CMTime {
		convert(reference: .zero)
	}
	@inline(__always)
	@inlinable
	public var base: CMTime {
		source.time
	}
	@inline(__always)
	@inlinable
	public func set(rate: Float64) throws {
		try setRate(rate)
	}
	@inline(__always)
	@inlinable
	public func set(time: CMTime) throws {
		try setTime(time)
	}
	@inline(__always)
	@inlinable
	public func set(rate: Float64, time anchor: CMTime, from reference: CMTime) throws {
		try setRateAndAnchorTime(rate: rate, anchorTime: anchor, referenceTime: reference)
	}
}
extension CMTimebase {
	public func tick(every period: CMTime, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<CMTime, any Swift.Error> & Sendable {
		AsyncThrowingStream { future in
			let period = CMTimeAbsoluteValue(period)
			let source = DispatchSource.makeTimerSource(queue: queue)
			let center = NotificationCenter.default
			let update = center.addObserver(forName: .CMTimebaseNotificationTimeJumped, object: self, queue: .none) {
				do {
					guard source.data == 1,
						let self = $0.object as?Self,
						let info = $0.userInfo?[kCMTimebaseNotificationKey_EventTime]as?Dictionary<String, Any>,
						let value = info["value"]as?CMTimeValue,
						let timescale = info["timescale"]as?CMTimeScale else { return }
					let time = CMTime(value: value, timescale: timescale).quantise(by: period, rounding: .roundTowardNegativeInfinity)
					let next = CMTimeAdd(time, period)
					try self.setTimerNextFireTime(source, fireTime: next)
				} catch {
					future.finish(throwing: error)
				}
			}
			future.onTermination = {
				switch $0 {
				case.cancelled:
					break
				case.finished:
					break
				@unknown default:
					break
				}
				source.cancel()
			}
			source.setRegistrationHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 0)
				let time = self.time.quantise(by: period, rounding: .roundTowardNegativeInfinity)
				let next = CMTimeAdd(time, period)
				do {
					try self.addTimer(source)
					try self.setTimerNextFireTime(source, fireTime: next)
				} catch {
					future.finish(throwing: error)
				}
			}
			source.setEventHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 1)
				let time = self.time.quantise(by: period, rounding: .roundTowardNegativeInfinity)
				let next = CMTimeAdd(time, period)
				future.yield(time)
				do {
					try self.setTimerNextFireTime(source, fireTime: next)
				} catch {
					future.finish(throwing: error)
				}
			}
			source.setCancelHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 0)
				center.removeObserver(update)
				do {
					try self.removeTimer(source)
				} catch {
					future.finish(throwing: error)
				}
			}
			source.resume()
		}
	}
}
extension CMTimebase {
	@discardableResult
	public func wait(until time: CMTime, on queue: Optional<DispatchQueue> = .none) async throws -> CMTime {
		try await withCheckedThrowingContinuation { future in
			let source = DispatchSource.makeTimerSource(queue: queue)
			let center = NotificationCenter.default
			let update = center.addObserver(forName: .CMTimebaseNotificationTimeJumped, object: self, queue: .none) {
				do {
					guard source.data == 1,
						let self = $0.object as?Self,
						let info = $0.userInfo?[kCMTimebaseNotificationKey_EventTime]as?Dictionary<String, Any>,
						let value = info["value"]as?CMTimeValue,
						let timescale = info["timescale"]as?CMTimeScale else { return }
					switch CMTimeCompare(time, .init(value: value, timescale: timescale)) {
					case let result where result < 0:
						try self.setTimerToFireImmediately(source) // strong reference `source`, removeObserver is required
					case let result where 0 < result:
						break
					case let result:
						assert(result == 0)
					}
				} catch {
					future.resume(throwing: error)
				}
			}
			source.setRegistrationHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 0)
				do {
					try self.addTimer(source)
					try self.setTimerNextFireTime(source, fireTime: time)
				} catch {
					future.resume(throwing: error)
					source.cancel()
				}
			}
			source.setEventHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 1)
				future.resume(returning: time)
				source.cancel()
			}
			source.setCancelHandler { [weak source] in
				guard let source else { return }
				assert(source.data == 0)
				center.removeObserver(update) // strong reference
				try?self.removeTimer(source)
			}
			source.resume()
		}
	}
}
extension CMTimebase: @retroactive Clock {
	public typealias Duration = CMTime
	public typealias Instant = CMTime
	public var now: Instant { time }
	public var minimumResolution: CMTime {
		.init(value: 1, timescale: now.timescale)
	}
	public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		try await wait(until: deadline)
	}
}
extension Notification.Name {
	static let CMTimebaseNotificationTimeJumped = Self(kCMTimebaseNotification_TimeJumped as String)
	static let CMTimebaseNotificationEffectiveRateChanged = Self(kCMTimebaseNotification_EffectiveRateChanged as String)
}
