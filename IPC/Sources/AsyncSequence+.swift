//
//  AsyncSequence+.swift
//  MUCE
//
//  Created by Kota on 4/3/R7.
//
@preconcurrency import typealias Combine.PassthroughSubject
extension AsyncSequence where Element == Void, Failure == Never {
	public var await: Element {
		get async {
			for await () in self {}
		}
	}
}
extension AsyncSequence where Element == Void {
	public var await: Element {
		get async throws (Failure) {
			for try await () in self {}
		}
	}
}
extension PassthroughSubject: @retroactive @unchecked Sendable {}
extension AsyncSequence where Self: Sendable {
	public var broadcast: some AsyncSequence<Element, any Error> & Sendable {
		let proxy = PassthroughSubject<Element, Failure>()
		let event = Task {
			do throws (Failure) {
				for try await value in self {
					proxy.send(value)
				}
			} catch {
				proxy.send(completion: .failure(error))
			}
		}
		return proxy.handleEvents(receiveCancel: event.cancel).values
	}
}
