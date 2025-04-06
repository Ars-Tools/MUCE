//
//  Socket.swift
//  MUCE
//
//  Created by Kota on 3/28/R7.
//
import func Darwin.dup
import func Darwin.getsockopt
import func Darwin.setsockopt
import let Darwin.errno
import typealias Darwin.socklen_t
import typealias Network.NWError
protocol Socket<Endpoint>: Com {
	associatedtype Endpoint: IPEndpoint
}
extension Socket {
	@inlinable
	@inline(__always)
	func setsockopt<T: BitwiseCopyable>(level: Int32, name: Int32, value: T) -> Result<(), NWError> {
		withUnsafeBytes(of: value) {
			Darwin.setsockopt(handle, level, name, $0.baseAddress, .init($0.count)) == 0 ?
				.success(()) :
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		}
	}
	@inlinable
	@inline(__always)
	func getsockopt<R: BitwiseCopyable>(level: Int32, name: Int32) -> Result<R, NWError> {
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<R>.stride + MemoryLayout<socklen_t>.size,
									  alignment: MemoryLayout<R>.alignment) {
			$0.storeBytes(of: socklen_t(MemoryLayout<R>.size),
						  toByteOffset: MemoryLayout<R>.stride,
						  as: socklen_t.self)
			return Darwin.getsockopt(handle, level, name,
									 $0.baseAddress,
									 $0.dropFirst(MemoryLayout<R>.stride).assumingMemoryBound(to: socklen_t.self).baseAddress) == 0 ?
				.success($0.load(as: R.self)) :
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		}
	}
}
