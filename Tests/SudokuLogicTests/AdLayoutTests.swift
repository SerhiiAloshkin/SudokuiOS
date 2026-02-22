import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class AdLayoutTests: XCTestCase {
    
    func testBannerAdViewInit() {
        let view = BannerAdView()
        XCTAssertNotNil(view, "BannerAdView should initialize")
    }
}
