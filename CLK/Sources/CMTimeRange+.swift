//
//  Untitled.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
@_exported @preconcurrency public import typealias CoreMedia.CMTimeRange
extension CMTimeRange {
	@inlinable @inline(__always)
	public static func~=(lhs: Self, rhs: CMTime) -> Bool {
		lhs.containsTime(rhs)
	}
}
