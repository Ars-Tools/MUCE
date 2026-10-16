// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "MUCE",
	platforms: [
		.tvOS(.v26),
		.iOS(.v26),
		.macCatalyst(.v26),
		.macOS(.v26)
	],
    products: [
		.library(
			name: "MUCE.Communications",
			targets: ["IPC"]
		),
		.library(
			name: "MUCE.Chrono",
			targets: ["CLK"]
		),
		.library(
			name: "MUCE.OSC",
			targets: ["OSC"]
		),
        .library(
            name: "MUCE.FSC",
            targets: ["FSC"]
        ),
		.library(
			name: "MUCE.RTP",
			targets: ["RTP"]
		),
		.library(
			name: "MUCE.Auxiliary",
			targets: ["Auxiliary"]
		),
    ],
    targets: [
		.target(
			name: "Auxiliary",
			path: "Auxiliary/Sources"
		),
		.testTarget(
			name: "AuxiliaryTests",
			dependencies: ["Auxiliary"],
			path: "Auxiliary/Tests"
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
//		.target(
//			name: "MPC",
//			dependencies: ["IPC"],
//			path: "MPC/Sources"
//		),
//		.testTarget(
//			name: "MPCTests",
//			dependencies: ["MPC"],
//			path: "MPC/Tests"
//		),
		.target(
			name: "CLK",
			dependencies: ["IPC", "Auxiliary"],
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
			dependencies: ["IPC", "Auxiliary"],
			path: "OSC/Sources"
		),
		.testTarget(
			name: "OSCTests",
			dependencies: ["OSC"],
			path: "OSC/Tests"
		),
        .target(
            name: "FSC",
            dependencies: ["IPC", "Auxiliary"],
            path: "FSC/Sources"
        ),
        .testTarget(
            name: "FSCTests",
            dependencies: ["FSC", "Auxiliary"],
            path: "FSC/Tests"
        )
//		.target(
//			name: "AAC",
//			dependencies: ["IPC"],
//			path: "AAC/Sources"
//		),
//		.testTarget(
//			name: "AACTests",
//			dependencies: ["AAC"],
//			path: "AAC/Tests"
//		)
    ]
)
