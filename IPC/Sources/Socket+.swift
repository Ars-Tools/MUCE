//
//  Socket+.swift
//  MUCE
//
//  Created by Kota on 3/29/R7.
//
import let Darwin.SO_RCVTIMEO
import let Darwin.SO_SNDTIMEO
import let Darwin.SO_REUSEADDR
import let Darwin.SO_REUSEPORT
import let Darwin.SOL_SOCKET
import let Darwin.IPPROTO_IP
import func Darwin.getsockname
import let Darwin.errno
import typealias Darwin.socklen_t
import typealias Darwin.sockaddr
import typealias Darwin.timeval
import typealias Network.NWError
extension Socket {
	public var reuseAddr: Bool {
		get {
			switch getsockopt(level: SOL_SOCKET, name: SO_REUSEADDR) as Result<Int32, NWError> {
			case.success(1...):
				true
			case.success,.failure:
				false
			}
		}
		set {
			switch setsockopt(level: SOL_SOCKET, name: SO_REUSEADDR, value: newValue ? 1 : 0 as Int32) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
}
extension Socket {
	public var reusePort: Bool {
		get {
			switch getsockopt(level: SOL_SOCKET, name: SO_REUSEPORT) as Result<Int32, NWError> {
			case.success(1...):
				true
			case.success,.failure:
				false
			}
		}
		set {
			switch setsockopt(level: SOL_SOCKET, name: SO_REUSEPORT, value: newValue ? 1 : 0 as Int32) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
}
extension Socket {
	public var timeoutRecv: Duration {
		get {
			switch getsockopt(level: SOL_SOCKET, name: SO_RCVTIMEO) as Result<timeval, NWError> {
			case.success(let timeval):
				.init(timeval)
			case.failure:
				.zero
			}
		}
		set {
			switch setsockopt(level: SOL_SOCKET, name: SO_RCVTIMEO, value: timeval(newValue)) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
	public var timeoutSend: Duration {
		get {
			switch getsockopt(level: SOL_SOCKET, name: SO_SNDTIMEO) as Result<timeval, NWError> {
			case.success(let timeval):
				.init(timeval)
			case.failure:
				.zero
			}
		}
		set {
			switch setsockopt(level: SOL_SOCKET, name: SO_SNDTIMEO, value: timeval(newValue)) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
}
extension Socket {
	@inlinable
	func getname() -> Result<Endpoint, NWError> {
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Endpoint>.stride + MemoryLayout<socklen_t>.size,
									  alignment: MemoryLayout<Endpoint>.alignment) {
			$0.storeBytes(of: socklen_t(MemoryLayout<Endpoint>.size),
						  toByteOffset: MemoryLayout<Endpoint>.stride,
						  as: socklen_t.self)
			return Darwin.getsockname(handle,
									  $0.assumingMemoryBound(to: sockaddr.self).baseAddress,
									  $0.dropFirst(MemoryLayout<Endpoint>.stride).assumingMemoryBound(to: socklen_t.self).baseAddress) == 0 ?
				.success($0.load(as: Endpoint.self)) :
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		}
	}
	public var name: Endpoint {
		get throws (NWError) {
			try getname().get()
		}
	}
}
