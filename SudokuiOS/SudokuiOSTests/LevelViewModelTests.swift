#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

class LevelViewModelTests: XCTestCase {
    
    var viewModel: LevelViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = LevelViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Initial state depends on timing, but ensure progress starts at 0 or 0.85 (due to immediate withAnimation in init)
        XCTAssertTrue(viewModel.isLoading)
    }
    
    func testAsyncProgressLoading() async {
        // 1. Initialize ViewModel (triggers loadLevelsWithProgress)
        let viewModel = await LevelViewModel()
        
        // 2. Poll for loading completion
        var timeout = 5.0
        while await viewModel.isLoading && timeout > 0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            timeout -= 0.1
        }
        
        // 3. Verify Final State
        let isDone = await viewModel.isLoading == false
        XCTAssertTrue(isDone, "Loading should complete within timeout")
        
        let hasLevels = await !viewModel.levels.isEmpty
        XCTAssertTrue(hasLevels, "Levels should be populated")
        
        let progress = await viewModel.loadingProgress
        XCTAssertEqual(progress, 1.0, "Progress should be 100%")
    }
    
    func testGetLevelBoundsSafety() {
        // 1. Valid bounds
        let validLevel = viewModel.getLevel(by: 1)
        XCTAssertNotNil(validLevel)
        
        // 2. Lower bound out of range
        let tooLow = viewModel.getLevel(by: 0)
        XCTAssertNil(tooLow)
        
        // 3. Upper bound out of range
        let tooHigh = viewModel.getLevel(by: 9999)
        XCTAssertNil(tooHigh)
    }
    
    func testVariantRuleMapping() throws {
        // Mock JSON data for a level with variant rules
        let json = """
        [
            {
                "id": 999,
                "board": "000000000...",
                "solution": "...",
                "difficulty": "Hard",
                "ruleType": "killer,thermo",
                "types": ["killer", "thermo"],
                "cages": [{"sum": 10, "cells": [[0,0], [0,1]]}],
                "thermoPaths": [[[1,0], [2,0]]]
            }
        ]
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let levels = try decoder.decode([SudokuLevel].self, from: json)
        
        XCTAssertEqual(levels.count, 1)
        let level = levels[0]
        XCTAssertTrue(level.types.contains(.killer))
        XCTAssertTrue(level.types.contains(.thermo))
        XCTAssertNotNil(level.cages)
        XCTAssertNotNil(level.thermoPaths)
        XCTAssertEqual(level.cages?.count, 1)
        XCTAssertEqual(level.thermoPaths?.count, 1)
    }
}
#endif

