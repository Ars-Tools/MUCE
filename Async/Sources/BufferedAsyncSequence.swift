//
//  BufferedAsyncSequence.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
extension AsyncSequence where Self: Sendable, Element: Collection, Element.Element: Sendable, Failure == Never {
	public func resize(count: Int) -> some AsyncSequence<ArraySlice<Element.Element>, Failure> {
		AsyncStream { future in
			Task<Void, Never> {
				var buffer = Array<Element.Element>()
				for await values in self where !values.isEmpty {
					buffer.append(contentsOf: values)
					switch buffer.prefix(count) {
					case let result where result.count == count:
						defer {
							buffer.removeFirst(count)
						}
						future.yield(result)
					default:
						continue
					}
				}
			}
		}
	}
}
extension AsyncSequence where Self: Sendable, Element: Collection, Element.Element: Sendable {
	public func resize(count: Int) -> some AsyncSequence<ArraySlice<Element.Element>, any Error> {
		AsyncThrowingStream { future in
			Task<Void, Never> {
				do {
					var buffer = Array<Element.Element>()
					for try await values in self where !values.isEmpty {
						buffer.append(contentsOf: values)
						switch buffer.prefix(count) {
						case let result where result.count == count:
							defer {
								buffer.removeFirst(count)
							}
							future.yield(result)
						default:
							continue
						}
					}
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
