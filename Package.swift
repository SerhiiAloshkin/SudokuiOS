// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SudokuiOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SudokuLogic",
            targets: ["SudokuLogic"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SudokuLogic",
            path: "SudokuiOS",
            exclude: [
                "SudokuiOSApp.swift",
                "MainMenuView.swift",
                "Assets.xcassets",
                "Preview Content",
                "SudokuiOSTests"
            ],
            sources: [
                "LevelViewModel.swift",
                "LevelSelectionView.swift",
                "LevelSelectionViewModel.swift",
                "GameState.swift",
                "UserLevelProgress.swift",
                "SudokuGameView.swift",
                "NumberPadView.swift",
                "SudokuGameViewModel.swift",
                "SudokuValidator.swift",
                "SettingsView.swift",
                "AppSettings.swift",
                "MoveHistory.swift",
                "SandwichMath.swift",
                "SandwichHelperView.swift",
                "RulesView.swift",
                "PointingPairsSolver.swift"
            ],
            resources: [
                .process("Levels.json")
            ]
        ),
        .testTarget(
            name: "SudokuLogicTests",
            dependencies: ["SudokuLogic"],
            path: "Tests/SudokuLogicTests"
        ),
    ]
)
