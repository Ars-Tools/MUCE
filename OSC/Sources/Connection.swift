//
//  Connection.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import protocol IPC.IPEndpoint
import typealias IPC.Udp
import typealias IPC.Tcp
import typealias Dispatch.DispatchQueue
import typealias Network.NWError
import let Darwin.SOMAXCONN
extension Tcp.Socket {
	public func send(packet: Packet) throws (NWError) {
		var data = packet.encode() as Array<UInt8>
		while !data.isEmpty {
			try data.removeFirst(send(data: data))
		}
	}
	public func send(stream: some AsyncSequence<Packet, any Error> & Sendable, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<(), any Error> & Sendable {
		send(stream: stream.map { $0.encode() as Array<UInt8> }, on: queue)
	}
	public func recv(on queue: Optional<DispatchQueue> = .none, context: Context = .default) -> some AsyncSequence<Packet, any Error> & Sendable {
		recv(on: queue)
			.compactMap {
				Packet(decode: $0, context: context)
			}
	}
}
extension Udp.Socket {
	public func send(packet: Packet, to endpoint: Endpoint) throws (NWError) {
		var data = packet.encode() as Array<UInt8>
		while !data.isEmpty {
			try data.removeFirst(send(data: data, to: endpoint))
		}
	}
	public func send(stream: some AsyncSequence<(Packet, Endpoint), any Error> & Sendable, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<(), any Error> & Sendable {
		send(stream: stream.map { ($0.encode() as Array<UInt8>, $1) }, on: queue)
	}
	public func recv(on queue: Optional<DispatchQueue> = .none, context: Context = .default) -> some AsyncSequence<(Packet, Endpoint), any Error> & Sendable {
		recv(on: queue)
			.compactMap { packet, endpoint in
				Packet(decode: packet, context: context).map { ($0, endpoint) }
			}
	}
}
