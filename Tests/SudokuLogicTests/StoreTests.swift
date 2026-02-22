import XCTest
import SwiftUI
@testable import SudokuLogic

class StoreTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset AdFree state
        UserDefaults.standard.set(false, forKey: "isAdFree")
    }
    
    func testPurchaseFlow() {
        let store = StoreManager()
        
        XCTAssertFalse(store.isAdFree)
        
        let expectation = XCTestExpectation(description: "Purchase completes")
        
        store.purchaseRemoveAds()
        XCTAssertTrue(store.isPurchasing)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if store.isAdFree {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(store.isAdFree)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isAdFree"))
    }
    
    func testAdSuppression() {
        // Mock Purchase
        UserDefaults.standard.set(true, forKey: "isAdFree")
        
        // 1. Interstitial Manager
        let manager = InterstitialAdManager()
        var shown = false
        manager.showAd {
            shown = false // Should be skipped immediately via completion
        }
        
        // If manager respected flag, it calls completion without setting isAdPresented
        XCTAssertFalse(manager.isAdPresented, "Ad should not present if ad-free")
    }
}
