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
import let Darwin.IFNAMSIZ
import let Darwin.IOC_INOUT
import let Darwin.IOCPARM_MASK
import let Darwin.errno
import func Darwin.getsockname
import func Darwin.ioctl
import func Darwin.strlcpy
import typealias Darwin.socklen_t
import typealias Darwin.sockaddr
import typealias Darwin.timeval
import typealias Darwin.ifreq
import typealias Network.NWError
import typealias Network.IPv4Address
import typealias Network.IPv6Address
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
extension Socket where Endpoint == IPv4Endpoint {
    @inlinable
    func getMTU(name: UnsafePointer<CChar>) -> Result<Int, NWError> {
        var request = ifreq()
        let copied = withUnsafeMutableBytes(of: &request.ifr_name) {
            $0.withMemoryRebound(to: UInt8.self) {
                strlcpy($0.baseAddress, name, $0.count)
            }
        }
        assert(copied < .init(IFNAMSIZ))
        // Darwin _IOWR('i', 51, struct ifreq); the SDK macro is not imported into Swift.
        let command = UInt(IOC_INOUT)
        | ((UInt(MemoryLayout<ifreq>.size) & UInt(IOCPARM_MASK)) << 16)
        | (UInt(UInt8(ascii: "i")) << 8)
        | 51
        return ioctl(handle, command, &request) == .zero ?
            .success(.init(request.ifr_ifru.ifru_mtu)) :
            .failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
    }
}
