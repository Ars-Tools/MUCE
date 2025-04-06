//
//  Sync.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import Testing
import typealias Network.NWEndpoint
import protocol IPC.IPEndpoint
import typealias IPC.IPv4Endpoint
import typealias IPC.IPv6Endpoint
@testable import CLK
@Suite
struct SyncTests {
	func sync<Endpoint: IPEndpoint>(endpoint: Endpoint, ε: Float64 = 1e-3) async throws {
		try await confirmation { confirmation in
			let server = try CMTimebase(sourceClock: .hostTimeClock)
			try server.set(rate: 1.5)
			let client = try CMTimebase(sourceClock: .hostTimeClock)
			try client.set(rate: 1.0)
			Task {
				try await server.export(to: endpoint)
			}
			Task {
				try await client.import(from: endpoint)
			}
			for try await () in client.tick(every: 1).map({_ in}) where client.rate.distance(to: 1.5).magnitude.isLess(than: ε) {
				confirmation.confirm()
				break
			}
		}
	}
	@Test(.timeLimit(.minutes(1)), arguments: [33401])
	func v4(port: NWEndpoint.Port) async throws {
		try await sync(endpoint: IPv4Endpoint(addr: .loopback, port: port))
	}
	@Test(.timeLimit(.minutes(1)), arguments: [33601])
	func v6(port: NWEndpoint.Port) async throws {
		try await sync(endpoint: IPv6Endpoint(addr: .loopback, port: port))
	}
}
