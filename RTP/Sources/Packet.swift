//
//  RTP.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
import protocol IPC.IPEndpoint
import typealias IPC.IPv4Endpoint
import typealias IPC.IPv6Endpoint
public enum RTP: Sendable {}
extension RTP {
	public struct Encoder: Sendable {
		@usableFromInline let ssrc: UInt32
		@usableFromInline let csrc: Array<UInt32>
		@usableFromInline let type: RTP.Packet.`Type`
	}
	public struct Decoder: Sendable {
		@usableFromInline let ssrc: UInt32
	}
}
extension RTP.Encoder {
	public func process(stream: some AsyncSequence<(UInt32, Array<UInt8>), any Error> & Sendable) -> some AsyncSequence<Array<UInt8>, any Error> & Sendable {
		AsyncThrowingStream { future in
			Task<Void, Never> {
				do {
					var sequence = UInt16.random(in: .min ... .max)
					for try await (timestamp, payload) in stream {
						sequence = sequence &+ 1
						future.yield(RTP.Packet(
							source: ssrc,
							contributions: csrc,
							sequence: sequence,
							timestamp: timestamp,
							type: type,
							payload: payload
						).encode())
					}
					future.finish()
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
extension RTP.Decoder {
	public func process(stream: some AsyncSequence<Array<UInt8>, any Error> & Sendable) -> some AsyncSequence<(UInt32, Array<UInt8>), any Error> & Sendable {
		AsyncThrowingStream { future in
			Task<Void, Never> {
				do {
					var latest = 0
					for try await packet in stream.map(RTP.Packet.init(from:)) where packet.synchronization == ssrc {
						future.yield((packet.timestamp, packet.payload))
					}
				} catch {
					
				}
			}
		}
	}
}
