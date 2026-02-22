import Foundation
import GoogleMobileAds

struct EnvironmentConfig {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var bannerAdUnitID: String {
        if isDebug {
            return "ca-app-pub-3940256099942544/2934735716" // Official Test ID
        } else {
            return "LIVE_ID_PLACEHOLDER" // To be replaced in production
        }
    }
    
    static var interstitialAdUnitID: String {
        if isDebug {
            return "ca-app-pub-3940256099942544/4411468910" // Official Test Interstitial ID
        } else {
            return "LIVE_INTERSTITIAL_ID_PLACEHOLDER"
        }
    }
    
    static var rewardedAdUnitID: String {
        if isDebug {
            return "ca-app-pub-3940256099942544/1712485313" // Official Test Rewarded ID
        } else {
            return "LIVE_REWARDED_ID_PLACEHOLDER"
        }
    }
    static var maxAdContentRating: GADMaxAdContentRating {
        return .general
    }
}
