import SwiftUI
import GoogleMobileAds
import OSLog

private let stokeBridgeLogger = Logger(subsystem: "com.stoke.blocks", category: "Bridge")

// MARK: - Content View

struct ContentView: View {
    var body: some View {
        GameView()
            .preferredColorScheme(.dark)
    }
}

// MARK: - Native AdMob Bridge

@MainActor
final class NativeAdMobBridge: NSObject, FullScreenContentDelegate, BannerViewDelegate {
    static let shared = NativeAdMobBridge()

    private enum AdUnitID {
        static let banner = "ca-app-pub-7262617456411456/9508273591"
        static let interstitial = "ca-app-pub-7262617456411456/6307395181"
        static let rewarded = "ca-app-pub-7262617456411456/7812048544"
    }

    private var didInitialize = false
    private var bannerView: BannerView?
    private var bannerConstraints: [NSLayoutConstraint] = []
    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?

    func handle(_ body: [String: Any]) {
        guard let action = body["action"] as? String else { return }
        let options = body["options"] as? [String: Any]

        switch action {
        case "initialize":
            initialize()
        case "showBanner":
            showBanner(adUnitID: adUnitID(from: options, fallback: AdUnitID.banner), options: options)
        case "removeBanner":
            removeBanner()
        case "prepareInterstitial":
            prepareInterstitial(adUnitID: adUnitID(from: options, fallback: AdUnitID.interstitial))
        case "showInterstitial":
            showInterstitial()
        case "prepareRewardVideoAd":
            prepareRewarded(adUnitID: adUnitID(from: options, fallback: AdUnitID.rewarded))
        case "showRewardVideoAd":
            showRewarded()
        default:
            stokeBridgeLogger.error("Unknown AdMob action: \(action, privacy: .public)")
        }
    }

    private func initialize() {
        guard !didInitialize else { return }
        didInitialize = true
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "71421e1a66f936bd9af28876132fb06a"
        ]
        stokeBridgeLogger.notice("Starting Google Mobile Ads SDK")
        MobileAds.shared.start()
    }

    private func showBanner(adUnitID: String, options: [String: Any]?) {
        initialize()
        guard let rootViewController = currentRootViewController(),
              let hostView = currentKeyWindow() else {
            stokeBridgeLogger.error("Unable to show banner: missing root view controller or key window")
            return
        }

        let adSize = AdSizeBanner
        let banner = bannerView ?? BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController
        banner.delegate = self
        banner.adSize = adSize

        if banner.superview !== hostView {
            banner.removeFromSuperview()
            banner.translatesAutoresizingMaskIntoConstraints = false
            hostView.addSubview(banner)
        }

        NSLayoutConstraint.deactivate(bannerConstraints)
        bannerConstraints = [
            banner.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor)
        ]
        NSLayoutConstraint.activate(bannerConstraints)

        bannerView = banner
        banner.load(Request())
        stokeBridgeLogger.notice("Requested banner ad anchored to bottom center")
    }

    private func removeBanner() {
        NSLayoutConstraint.deactivate(bannerConstraints)
        bannerConstraints = []
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
        stokeBridgeLogger.notice("Removed banner ad")
    }

    private func prepareInterstitial(adUnitID: String) {
        initialize()
        Task { @MainActor in
            do {
                interstitialAd = try await InterstitialAd.load(with: adUnitID, request: Request())
                interstitialAd?.fullScreenContentDelegate = self
                stokeBridgeLogger.notice("Interstitial ad loaded")
            } catch {
                interstitialAd = nil
                stokeBridgeLogger.error("Interstitial ad failed to load: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func showInterstitial() {
        initialize()
        guard let rootViewController = currentRootViewController(), let interstitialAd else {
            stokeBridgeLogger.error("Unable to show interstitial: ad or root view controller missing")
            return
        }
        interstitialAd.present(from: rootViewController)
        self.interstitialAd = nil
    }

    private func prepareRewarded(adUnitID: String) {
        initialize()
        Task { @MainActor in
            do {
                rewardedAd = try await RewardedAd.load(with: adUnitID, request: Request())
                rewardedAd?.fullScreenContentDelegate = self
                stokeBridgeLogger.notice("Rewarded ad loaded")
            } catch {
                rewardedAd = nil
                stokeBridgeLogger.error("Rewarded ad failed to load: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func showRewarded() {
        initialize()
        guard let rootViewController = currentRootViewController(), let rewardedAd else {
            stokeBridgeLogger.error("Unable to show rewarded ad: ad or root view controller missing")
            NotificationCenter.default.post(name: .rewardedAdFailed, object: nil)
            return
        }
        rewardedAd.present(from: rootViewController) {
            NotificationCenter.default.post(name: .rewardedAdEarned, object: nil)
        }
        self.rewardedAd = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        stokeBridgeLogger.error("Full-screen ad failed to present: \(error.localizedDescription, privacy: .public)")
        NotificationCenter.default.post(name: .rewardedAdFailed, object: nil)
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        stokeBridgeLogger.notice("Banner ad loaded")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        stokeBridgeLogger.error("Banner ad failed to load: \(error.localizedDescription, privacy: .public)")
    }

    private func adUnitID(from options: [String: Any]?, fallback: String) -> String {
        guard let adUnitID = options?["adId"] as? String, !adUnitID.isEmpty else { return fallback }
        return adUnitID
    }

    private func currentRootViewController() -> UIViewController? {
        currentKeyWindow()?.rootViewController
    }

    private func currentKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let rewardedAdEarned = Notification.Name("rewardedAdEarned")
    static let rewardedAdFailed = Notification.Name("rewardedAdFailed")
}

#Preview {
    ContentView()
}
