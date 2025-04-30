// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "MUCE",
	platforms: [
		.tvOS(.v18),
		.iOS(.v18),
		.macCatalyst(.v18),
		.macOS(.v15)
	],
    products: [
		.library(
			name: "MUCE",
			targets: [
				"IPC",
				"CLK",
				"RTP",
				"OSC",
				"AAC",
				"Async"
			]
		)
    ],
    targets: [
		.target(
			name: "Async",
			path: "Async/Sources"
		),
		.testTarget(
			name: "AsyncTests",
			dependencies: ["Async"],
			path: "Async/Tests"
		),
		.target(
			name: "IPC",
			path: "IPC/Sources"
		),
		.testTarget(
			name: "IPCTests",
			dependencies: ["IPC"],
			path: "IPC/Tests"
		),
		.target(
			name: "CLK",
			dependencies: ["IPC"],
			path: "CLK/Sources"
		),
		.testTarget(
			name: "CLKTests",
			dependencies: ["CLK"],
			path: "CLK/Tests"
		),
		.target(
			name: "RTP",
			dependencies: ["IPC"],
			path: "RTP/Sources"
		),
		.testTarget(
			name: "RTPTests",
			dependencies: ["RTP"],
			path: "RTP/Tests"
		),
		.target(
			name: "OSC",
			dependencies: ["IPC"],
			path: "OSC/Sources"
		),
		.testTarget(
			name: "OSCTests",
			dependencies: ["OSC"],
			path: "OSC/Tests"
		),
		.target(
			name: "AAC",
			dependencies: ["IPC"],
			path: "AAC/Sources"
		),
		.testTarget(
			name: "AACTests",
			dependencies: ["AAC"],
			path: "AAC/Tests"
		)
    ]
)
