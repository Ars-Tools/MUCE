//
//  BufferedAsyncSequence.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
extension AsyncSequence where Self: Sendable, Element: Sendable, Failure == Never {
	public func buffer(count: Int) -> some AsyncSequence<ArraySlice<Element>, Failure> {
		AsyncStream { future in
			Task<Void, Never> {
				var buffer = ArraySlice<Element>()
				for await value in self {
					buffer.append(value)
					switch buffer.prefix(count) {
					case let prefix where prefix.count == count:
						defer {
							buffer.removeFirst(prefix.count)
						}
						future.yield(prefix)
					default:
						continue
					}
				}
				while !buffer.isEmpty {
					let prefix = buffer.prefix(count)
					defer {
						buffer.removeFirst(prefix.count)
					}
					future.yield(prefix)
				}
				future.finish()
			}
		}
	}
}
extension AsyncSequence where Self: Sendable, Element: Sendable {
	public func buffer(count: Int) -> some AsyncSequence<ArraySlice<Element>, any Error> {
		AsyncThrowingStream { future in
			Task<Void, Never> {
				do {
					var buffer = ArraySlice<Element>()
					for try await value in self {
						buffer.append(value)
						switch buffer.prefix(count) {
						case let prefix where prefix.count == count:
							defer {
								buffer.removeFirst(prefix.count)
							}
							future.yield(prefix)
						default:
							continue
						}
					}
					while !buffer.isEmpty {
						let prefix = buffer.prefix(count)
						defer {
							buffer.removeFirst(prefix.count)
						}
						future.yield(prefix)
					}
					future.finish()
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
extension AsyncSequence where Self: Sendable, Element: Collection, Element.Element: Sendable, Failure == Never {
	public func resize(count: Int) -> some AsyncSequence<ArraySlice<Element.Element>, Failure> {
		AsyncStream { future in
			Task<Void, Never> {
				var buffer = ArraySlice<Element.Element>()
				for await values in self where !values.isEmpty {
					buffer.append(contentsOf: values)
					switch buffer.prefix(count) {
					case let result where result.count == count:
						defer {
							buffer.removeFirst(result.count)
						}
						future.yield(result)
					default:
						continue
					}
				}
				while !buffer.isEmpty {
					let prefix = buffer.prefix(count)
					defer {
						buffer.removeFirst(prefix.count)
					}
					future.yield(prefix)
				}
				future.finish()
			}
		}
	}
}
extension AsyncSequence where Self: Sendable, Element: Collection, Element.Element: Sendable {
	public func resize(count: Int) -> some AsyncSequence<ArraySlice<Element.Element>, any Error> {
		AsyncThrowingStream { future in
			Task<Void, Never> {
				do {
					var buffer = ArraySlice<Element.Element>()
					for try await values in self where !values.isEmpty {
						buffer.append(contentsOf: values)
						switch buffer.prefix(count) {
						case let result where result.count == count:
							defer {
								buffer.removeFirst(result.count)
							}
							future.yield(result)
						default:
							continue
						}
					}
					while !buffer.isEmpty {
						let prefix = buffer.prefix(count)
						defer {
							buffer.removeFirst(prefix.count)
						}
						future.yield(prefix)
					}
					future.finish()
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
