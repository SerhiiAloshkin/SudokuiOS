import XCTest
@testable import SudokuLogic

class EnvironmentTests: XCTestCase {
    
    func testDebugConfig() {
        // This test runs in Debug configuration by default in Xcode
        #if DEBUG
        XCTAssertTrue(EnvironmentConfig.isDebug, "Should be in Debug mode")
        XCTAssertEqual(EnvironmentConfig.bannerAdUnitID, "ca-app-pub-3940256099942544/2934735716", "Should use Test ID")
        #else
        XCTAssertFalse(EnvironmentConfig.isDebug, "Should be in Release mode")
        #endif
    }
}
