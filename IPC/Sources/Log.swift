//
//  Log.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
import func os.os_log
import typealias Network.NWError
func log(info error: NWError) {
	os_log(.info, "%{public}@", String(describing: error))
}
func log(debug error: NWError) {
	os_log(.debug, "%{public}@", String(describing: error))
}
