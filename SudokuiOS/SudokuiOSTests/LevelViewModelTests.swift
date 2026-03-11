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
        XCTAssertFalse(viewModel.appIsReady)
        XCTAssertTrue(viewModel.levels.isEmpty)
    }
    
    func testAsyncProgressLoading() async {
        // 1. Initialize ViewModel (Lightweight)
        let viewModel = await LevelViewModel()
        XCTAssertFalse(await viewModel.appIsReady)
        
        // 2. Trigger background load
        await viewModel.loadLevelsData()
        
        // 3. Verify Data
        let hasLevels = await !viewModel.levels.isEmpty
        XCTAssertTrue(hasLevels, "Levels should be populated")
        
        // Note: appIsReady is controlled by SplashView in the app, 
        // so we don't assert it here unless we simulate the SplashView logic.
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

