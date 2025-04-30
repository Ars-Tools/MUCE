//
//  Opus.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
import Testing
import AVFoundation
@Suite
struct Suite {
	@Test(arguments: [] as [Int])
	func encode(channel: Int) {
		let layout = AudioChannelLayout.allocate(maximumDescriptions: channel)
		defer {
			layout.unsafePointer.deallocate()
		}
		let sample = 16000 as Float64
		var source = AudioStreamBasicDescription(mSampleRate: sample,
												 mFormatID: kAudioFormatLinearPCM,
												 mFormatFlags: kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked,
												 mBytesPerPacket: .init(4 * channel),
												 mFramesPerPacket: 1,
												 mBytesPerFrame: .init(4 * channel),
												 mChannelsPerFrame: .init(channel),
												 mBitsPerChannel: 32,
												 mReserved: 0)
//		var target = AudioStreamBasicDescription(mSampleRate: sample,
//												 mFormatID: kAudioFormatLinearPCM,
//												 mFormatFlags: kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked,
//												 mBytesPerPacket: .init(4 * channel),
//												 mFramesPerPacket: 1,
//												 mBytesPerFrame: .init(4 * channel),
//												 mChannelsPerFrame: .init(channel),
//												 mBitsPerChannel: 32,
//												 mReserved: 0)
		var target = AudioStreamBasicDescription(mSampleRate: sample,
												 mFormatID: kAudioFormatOpus,
												 mFormatFlags: 0,
												 mBytesPerPacket: 0,
												 mFramesPerPacket: 0,
												 mBytesPerFrame: 0,
												 mChannelsPerFrame: .init(channel),
												 mBitsPerChannel: 0,
												 mReserved: 0)
		var converter: AudioConverterRef?
		guard AudioConverterNew(&source, &target, &converter) == noErr, let converter else {
//			Issue.record()
			return
		}
		print(AVAudioFormat(streamDescription: &source), AVAudioFormat(streamDescription: &target))
		print("\(channel)=\(converter)")
	}
}
