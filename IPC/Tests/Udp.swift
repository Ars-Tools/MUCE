//
//  Udp.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
import Testing
import typealias Network.NWEndpoint
@testable import IPC
@Suite
struct UdpTests {
	func scenario<Endpoint: IPEndpoint>(endpoint: Endpoint) async throws {
		let socket = try Udp.Socket<Endpoint>()
		try socket.bind(on: endpoint)
		Task {
			try await socket.send(stream: socket.recv().map { ([$0.reduce(0, &+)], $1) }).await
		}
		let client = try Udp.Socket<Endpoint>()
		let req = repeatElement(UInt8.min ... UInt8.max, count: 64).map(UInt8.random(in:))
		async let res = client.recv().prefix(1).map(\.0).compactMap(\.first).reduce(0, &+)
		try client.send(data: req, to: endpoint)
		try await #expect(res == req.reduce(0, &+))
	}
	@Test(.timeLimit(.minutes(1)), arguments: [10401])
	func echoV4(port: NWEndpoint.Port) async throws {
		try await scenario(endpoint: IPv4Endpoint(addr: .loopback, port: port))
	}
	@Test(.timeLimit(.minutes(1)), arguments: [10601])
	func echoV6(port: NWEndpoint.Port) async throws {
		try await scenario(endpoint: IPv6Endpoint(addr: .loopback, port: port))
	}
	@Test
	func resolveV4() {
		let endpoints = Udp.Resolve(for: "localhost") as Set<IPv4Endpoint>
		#expect(0 < endpoints.lazy.map(\.addr).count(where: \.isLoopback))
	}
	@Test
	func resolveV6() {
		let endpoints = Udp.Resolve(for: "localhost") as Set<IPv6Endpoint>
		#expect(0 < endpoints.lazy.map(\.addr).count(where: \.isLoopback))
	}
}
