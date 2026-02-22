import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class CorrelationTests: XCTestCase {
    
    func testRestrictionColorExists() {
        let color = UIColor(named: "RestrictionHighlight")
        XCTAssertNotNil(color, "RestrictionHighlight asset should exist")
    }
}
