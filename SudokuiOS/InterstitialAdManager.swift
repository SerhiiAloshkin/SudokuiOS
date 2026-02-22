import SwiftUI
import Combine

class InterstitialAdManager: ObservableObject {
    @Published var isAdPresented: Bool = false
    @Published var isAdReady: Bool = false
    
    private var onDismiss: (() -> Void)?
    
    init() {
        // Simulation: Automatically "load" an ad
        loadAd()
    }
    
    func loadAd() {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAdReady = true
        }
    }
    
    func showAd(completion: @escaping () -> Void) {
        // Check IAP status directly from UserDefaults
        if UserDefaults.standard.bool(forKey: "isAdFree") {
            completion()
            return
        }
        
        guard isAdReady else {
            print("Ad not ready, skipping.")
            completion()
            return
        }
        
        self.onDismiss = completion
        self.isAdPresented = true
    }
    
    func dismissAd() {
        self.isAdPresented = false
        self.isAdReady = false // Consume ad
        self.onDismiss?()
        self.onDismiss = nil
        
        // Load next one
        loadAd()
    }
}
