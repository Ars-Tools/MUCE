//
//  Tcp.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
import Testing
import typealias Network.NWEndpoint
@testable import IPC
@Suite
struct TcpTests {
	func scenario<Endpoint: IPEndpoint>(endpoint: Endpoint) async throws {
		Task {
			try await Tcp.Incoming(on: endpoint)
				.flatMap { socket, endpoint in
					socket.send(stream: socket.recv().map { [$0.reduce(0, &+)] })
				}
				.await
		}
		try await Task.sleep(for: .seconds(1))
		let req = repeatElement(.min ... .max, count: 64).map(UInt8.random(in:))
		let client = try Tcp.Connect(to: endpoint)
		async let res = client.recv().prefix(1).compactMap(\.first).reduce(0, &+)
		try client.send(data: req)
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
		let endpoints = Tcp.Resolve(for: "localhost") as Set<IPv4Endpoint>
		#expect(0 < endpoints.lazy.map(\.addr).count(where: \.isLoopback))
	}
	@Test
	func resolveV6() {
		let endpoints = Tcp.Resolve(for: "localhost") as Set<IPv6Endpoint>
		#expect(0 < endpoints.lazy.map(\.addr).count(where: \.isLoopback))
	}
}
