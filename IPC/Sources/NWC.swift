//
//  NWC.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
import protocol Foundation.DataProtocol
import typealias Foundation.Data
import typealias Network.NWConnection
import typealias Network.NWError
extension NWConnection {
	public func send(data: some DataProtocol) async throws (NWError) {
		try await send(data: data).get()
	}
	public func send(data: some DataProtocol) async -> Result<Void, NWError> {
		await withCheckedContinuation { future in
			send(content: .init(data), completion: .contentProcessed {
				switch $0 {
				case.some(let error):
					future.resume(returning: .failure(error))
				case.none:
					future.resume(returning: .success(()))
				}
			})
		}
	}
	public func send(stream: some AsyncSequence<some DataProtocol, any Error> & Sendable) -> some AsyncSequence<Void, any Error> & Sendable {
		AsyncThrowingStream { future in
			Task {
				do {
					for try await data in stream {
						try await withCheckedThrowingContinuation { future in
							send(content: data, completion: .contentProcessed {
								switch $0 {
								case.some(let error):
									future.resume(throwing: error)
								case.none:
									future.resume()
								}
							})
						} as Void
						future.yield()
					}
					send(content: .none, isComplete: true, completion: .contentProcessed {
						switch $0 {
						case.some(let error):
							future.finish(throwing: error)
						case.none:
							future.finish()
						}
					})
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
