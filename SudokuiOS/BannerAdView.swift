import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable, Equatable {
    let adUnitID: String = EnvironmentConfig.bannerAdUnitID
    
    // Equatable: Only update if adUnitID changes (which is constant here, so effectively never re-renders)
    static func == (lhs: BannerAdView, rhs: BannerAdView) -> Bool {
        return lhs.adUnitID == rhs.adUnitID
    }
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        
        // Find root VC
        if let root = UIApplication.shared.firstKeyWindow?.rootViewController {
            banner.rootViewController = root
        }
        
        // Defer load to next run loop to avoid "NavigationRequestObserver" warnings during layout
        DispatchQueue.main.async {
            banner.load(Request())
        }
        
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
}

#Preview {
    BannerAdView()
}
