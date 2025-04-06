//
//  Connection.swift
//  MUCE
//
//  Created by Kota on 4/1/R7.
//
import Testing
import IPC
import typealias Network.NWEndpoint
@testable import OSC
@Suite
struct ConnectionTests {
	func udp<Endpoint: IPEndpoint>(on endpoint: Endpoint, handler: some Handler<String, Endpoint>, send packet: Packet) async throws {
		let server = try Udp.Socket<Endpoint>(on: endpoint)
		Task { try await server.send(stream: handler.process(stream: server.recv(), context: .default)).await }
		try await Task.sleep(for: .seconds(1)) // just hanging out
		let client = try Udp.Socket<Endpoint>()
		try client.send(packet: packet, to: endpoint)
		try await Task.sleep(for: .seconds(1)) // wait for event handling
	}
	func tcp<Endpoint: IPEndpoint>(on endpoint: Endpoint, handler: some Handler<String, Endpoint>, send packet: Packet) async throws {
		Task {
			try await Tcp.Incoming(on: endpoint)
				.flatMap { socket, endpoint in
					socket.send(stream: handler.process(stream: socket.recv().map { ($0, endpoint) }, context: .default).map(\.0))
				}.await
		}
		try await Task.sleep(for: .seconds(1)) // wait for socket binding & listen
		let client = try Tcp.Connect(to: endpoint)
		try client.send(packet: packet)
		try await Task.sleep(for: .seconds(1)) // wait for event handling
	}
	@Test(.timeLimit(.minutes(1)))
	func router() async throws {
		try await ((), ()) = confirmation(expectedCount: 4) { event in
			let random = .random(in: .min ... .max) as Int32
			var router = Router<IPv4Endpoint>()
			router.dispatch(for: "/abc/x") {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				return.none
			}
			router.dispatch(for: "/abc/y") {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				return.none
			}
			router.dispatch(for: "/ab/zw") {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				Issue.record()
				return.none
			}
			async let udp: () = udp(on: IPv4Endpoint(addr: .loopback, port: 26401), handler: router, send: .init(address: "/abc/?", with: [random]))
			async let tcp: () = tcp(on: IPv4Endpoint(addr: .loopback, port: 27401), handler: router, send: .init(address: "/abc/?", with: [random]))
			return try await (udp, tcp)
		}
	}
	@Test(.timeLimit(.minutes(1)))
	func matcher() async throws {
		try await ((), ()) = confirmation(expectedCount: 4) { event in
			let random = .random(in: .min ... .max) as Int32
			var matcher = Matcher<IPv4Endpoint>()
			matcher.dispatch(for: /ab./) {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				return.none
			}
			matcher.dispatch(for: /a.*/) {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				return.none
			}
			matcher.dispatch(for: /c.*/) {
				if case.ipv4(.loopback) = $3.host, case.some(random) = $1.first as?Int32 {
					event.confirm(count: 1)
				}
				Issue.record()
				return.none
			}
			async let udp: () = udp(on: IPv4Endpoint(addr: .loopback, port: 29401), handler: matcher, send: .init(address: "abc", with: [random]))
			async let tcp: () = tcp(on: IPv4Endpoint(addr: .loopback, port: 29402), handler: matcher, send: .init(address: "abc", with: [random]))
			return try await (udp, tcp)
		}
	}
}
