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
        // Since loading will be async, we might need to wait or check initial state before load
        // But for now, let's assume we want to test the full load
    }
    
    func testAsyncLevelLoading() async {
        // 1. Initialize ViewModel
        // Note: LevelViewModel is @MainActor, so this test should also be @MainActor or handled accordingly
        let expectation = XCTestExpectation(description: "Levels should load asynchronously")
        
        // 2. Observe isLoading (we'll add this property soon)
        // Since we can't easily use Combine here without more setup, we can poll or use a Task
        
        let viewModel = await LevelViewModel()
        
        // 3. Wait for loading to finish
        // We'll check if isLoading becomes false
        var timeout = 5.0
        while await viewModel.isLoading && timeout > 0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            timeout -= 0.1
        }
        
        XCTAssertFalse(await viewModel.isLoading, "Loading should complete")
        XCTAssertFalse(await viewModel.levels.isEmpty, "Levels should not be empty after loading")
        expectation.fulfill()
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

