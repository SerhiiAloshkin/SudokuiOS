import SwiftUI
import Combine
import GoogleMobileAds

@MainActor
final class AdCoordinator: NSObject, ObservableObject, FullScreenContentDelegate, @unchecked Sendable {
    @Published var isAdReady: Bool = false
    @Published var isShowingAd: Bool = false
    
    // Properties
    private var interstitial: InterstitialAd?
    private var rewardedAd: RewardedAd?
    private var onAdDismissed: (() -> Void)?
    private let networkMonitor = NetworkMonitor()
    
    override init() {
        super.init()
        loadAd()
        loadRewardedAd()
    }
    
    func loadAd() {
        if UserDefaults.standard.bool(forKey: "isAdsRemoved") { return }
        
        let request = Request()
        InterstitialAd.load(with: EnvironmentConfig.interstitialAdUnitID,
                               request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                    self?.isAdReady = false
                    return
                }
                self?.interstitial = ad
                self?.interstitial?.fullScreenContentDelegate = self
                self?.isAdReady = true
            }
        }
    }
    
    func loadRewardedAd() {
        if UserDefaults.standard.bool(forKey: "isAdsRemoved") { return }

        let request = Request()
        RewardedAd.load(with: EnvironmentConfig.rewardedAdUnitID, // Ensure this exists or use Test ID
                           request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                    return
                }
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                print("Rewarded Ad Loaded")
            }
        }
    }
    
    func showInterstitialAd(completion: @escaping () -> Void) {
        // 1. Check IAP
        if UserDefaults.standard.bool(forKey: "isAdsRemoved") {
            completion()
            return
        }
        
        // 2. Check Connection
        if !networkMonitor.isConnected {
            print("No internet connection. Skipping ad.")
            completion()
            return
        }
        
        // 3. Check Ad Availability
        if let interstitial = interstitial {
             self.onAdDismissed = completion
             
             if let topController = UIApplication.shared.topViewController {
                 interstitial.present(from: topController)
                 isShowingAd = true
             } else {
                 print("Root VC not found. Skipping ad.")
                 completion()
             }
        } else {
            print("Ad not ready. Skipping ad.")
            completion()
            // Try to reload for next time
            loadAd()
        }
    }
    
    func showRewardedVideo(completion: @escaping (Bool) -> Void) {
        // 1. Check Connection
        if !networkMonitor.isConnected {
            print("No internet connection. Cannot show rewarded ad.")
            completion(false)
            return
        }
        
        // 2. Check Ad Availability
        if let rewardedAd = rewardedAd {
             // Define Reward Handler
             if let topController = UIApplication.shared.topViewController {
                 rewardedAd.present(from: topController) {
                     // User Earned Reward
                     print("User earned reward.")
                     completion(true)
                 }
                 isShowingAd = true
                 self.onAdDismissed = nil // Only used for Interstital dismissal flow usually, but handled by delegate below
             } else {
                 print("Root VC not found.")
                 completion(false)
             }
        } else {
            print("Rewarded Ad not ready.")
            completion(false)
            // Try reload
            loadRewardedAd()
        }
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad dismissed.")
        isShowingAd = false
        
        // Check what kind of ad it was
        if ad is InterstitialAd {
             // Trigger completion on next run loop
             DispatchQueue.main.async { [weak self] in
                 self?.onAdDismissed?()
                 self?.onAdDismissed = nil
             }
             loadAd()
        } else if ad is RewardedAd {
             // Rewarded Ad handled via present callback for success,
             // but we need to reload.
             // If user closed EARLY without reward, the present handler above won't fire (or verified logic).
             // Actually, present handler fires Only on Reward.
             // If they dismiss early, we just reload.
             loadRewardedAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present with error: \(error.localizedDescription)")
        isShowingAd = false
        
        if ad is InterstitialAd {
            onAdDismissed?()
            onAdDismissed = nil
            loadAd()
        } else if ad is RewardedAd {
            loadRewardedAd()
        }
    }
}

// Helper for Root VC
extension UIApplication {
    var firstKeyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.keyWindow
    }
    
    var topViewController: UIViewController? {
        var top = firstKeyWindow?.rootViewController
        while true {
            if let presented = top?.presentedViewController {
                top = presented
            } else if let nav = top as? UINavigationController {
                top = nav.visibleViewController
            } else if let tab = top as? UITabBarController {
                top = tab.selectedViewController
            } else {
                break
            }
        }
        return top
    }
}
