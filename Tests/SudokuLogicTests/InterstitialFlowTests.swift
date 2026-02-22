import XCTest
import Combine
@testable import SudokuLogic

class InterstitialFlowTests: XCTestCase {
    
    func testAdLoadingAndShow() {
        let manager = InterstitialAdManager()
        
        // Initial State (Simulated loading async)
        XCTAssertFalse(manager.isAdReady) 
        
        let expectation = XCTestExpectation(description: "Ad eventually loads")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if manager.isAdReady {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Show Ad
        var dismissed = false
        manager.showAd {
            dismissed = true
        }
        
        XCTAssertTrue(manager.isAdPresented)
        
        // Dismiss
        manager.dismissAd()
        XCTAssertFalse(manager.isAdPresented)
        XCTAssertTrue(dismissed)
        XCTAssertFalse(manager.isAdReady, "Ad should be consumed")
    }
}
