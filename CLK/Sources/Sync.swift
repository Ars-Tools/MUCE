//
//  Sync.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias CoreMedia.CMTime
@preconcurrency import func CoreMedia.CMTimeMultiplyByRatio
@preconcurrency import func CoreMedia.CMTimeMultiplyByFloat64
@preconcurrency import func CoreMedia.CMTimeAbsoluteValue
import os.log
import IPC
public protocol SynchroniseSource: Sendable {
	var sign: CMTime { get }
	var base: CMTime { get }
	var time: CMTime { get }
	var rate: Float64 { get }
}
public protocol Synchronisable: SynchroniseSource {
	func set(rate: Float64) throws
	func set(rate: Float64, time anchor: CMTime, from reference: CMTime) throws
}
extension SynchroniseSource {
    public func`export`(to endpoint: some IPEndpoint, on queue: Optional<DispatchQueue> = .none) async throws {
		try await export(by: .init(on: endpoint), on: queue).await
	}
    public func`export`(by socket: Udp.Socket<some IPEndpoint>, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<(), any Error> {
		socket.send(stream: socket.recv(on: queue).compactMap { request, endpoint in
			let response = Array<UInt8>(unsafeUninitializedCapacity: MemoryLayout<CMTime>.stride * 4) {
				assert($0.count == MemoryLayout<CMTime>.stride * 4)
				guard $0.initialize(fromContentsOf: request) == MemoryLayout<CMTime>.stride * 2 else { return }
				$0.withMemoryRebound(to: CMTime.self) {
					($0[2], $0[3]) = (sign, time)
				}
				$1 = MemoryLayout<CMTime>.stride * 4
			}
			return response.count == MemoryLayout<CMTime>.stride * 4 ?
				.some((response, endpoint)) :
				.none
		}, on: queue)
	}
}
extension Synchronisable {
    public func`import`<Endpoint: IPEndpoint>(from endpoint: Endpoint, on queue: Optional<DispatchQueue> = .none) async throws {
        try await withThrowingTaskGroup {
            let socket = try Udp.Socket<Endpoint>()
            let notify = try CMTimebase(sourceClock: .hostTimeClock)
            try notify.set(rate: 1)
            $0.addTask {
                var anchor = (p: CMTime.invalid, t: CMTime.invalid, τ: CMTime.invalid, ε: CMTime.invalid)
                for try await (packet, response) in socket.recv(on: queue) where (packet.count, response) == (MemoryLayout<CMTime>.stride * 4, endpoint) {
                    let (n, r) = (time, base)
                    let (σ, s, p, τ) = packet.withUnsafeBytes { $0.loadUnaligned(as: (CMTime, CMTime, CMTime, CMTime).self) }
                    let t = CMTimeMultiplyByRatio(CMTimeAdd(r, s), multiplier: 1, divisor: 2)
                    let ε = CMTimeMultiplyByRatio(CMTimeSubtract(r, s), multiplier: 1, divisor: 2)
                    let χ = CMTimeSubtract(n, CMTimeMultiplyByFloat64(ε, multiplier: rate))
                    if σ != sign { // CMTimeCompare(σ, sign)
                        
                    } else if p != anchor.p {
                        anchor.ε = .positiveInfinity
                        anchor.p = p
                    } else if ε < anchor.ε {
                        anchor.ε = ε
                        anchor.τ = τ
                        anchor.t = t
                    } else if ε < CMTimeAbsoluteValue(CMTimeSubtract(τ, χ)) {
                        let dτ = τ - anchor.τ
                        let dt = t - anchor.t
                        let rate = dτ.seconds / dt.seconds
                        try set(rate: rate, time: τ, from: t)
                    } else {
    //                    let Δτ = τ - χ
                        let dτ = τ - anchor.τ
                        let dt = t - anchor.t
                        let rate = dτ.seconds / dt.seconds// + Δτ.seconds * anchor.ε.seconds / ε.seconds
                        try set(rate: rate)
                    }
                }
            }
            $0.addTask {
                for try await () in socket.send(stream: notify.tick(every: 1, on: queue).map { elapse in
                    (withUnsafeBytes(of: (sign, base), Array<UInt8>.init), endpoint)
                }, on: queue) {
                    
                }
            }
        }
	}
}
