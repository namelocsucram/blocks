//
//  ContentView.swift
//  blocks
//
//  Created by Owner on 7/25/26.
//

import SwiftUI
import WebKit
import Combine
import RevenueCat
import GoogleMobileAds
import OSLog

private let stokeBridgeLogger = Logger(subsystem: "com.stoke.blocks", category: "Bridge")

enum NativeBridgeMode {
    case disabled
    case storageOnly
    case storageAndAds
    case storageAdsAndPurchases
    
    var includesStorage: Bool {
        switch self {
        case .storageOnly, .storageAndAds, .storageAdsAndPurchases:
            return true
        case .disabled:
            return false
        }
    }
    
    var includesAdMob: Bool {
        switch self {
        case .storageAndAds, .storageAdsAndPurchases:
            return true
        case .disabled, .storageOnly:
            return false
        }
    }
    
    var includesPurchases: Bool {
        switch self {
        case .storageAdsAndPurchases:
            return true
        case .disabled, .storageOnly, .storageAndAds:
            return false
        }
    }
}

struct ContentView: View {
    @StateObject private var messageHandler = WebViewMessageHandler()
    @State private var webView: WKWebView?

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.03, blue: 0.12)
                .ignoresSafeArea()

            if Self.isRunningForPreviews {
                PreviewShellView()
            } else {
                WebViewContainer(
                    htmlFileName: "index",
                    messageHandler: messageHandler,
                    webView: $webView,
                    bridgeMode: Self.defaultBridgeMode
                )
                .ignoresSafeArea()
                .overlay(
                    // Visual aiming aid: small cursor above the finger during drags
                    TouchCursorOverlay(targetView: webView)
                )
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
    
    private static var defaultBridgeMode: NativeBridgeMode {
        let processInfo = ProcessInfo.processInfo
        let storageBridgeEnabled = processInfo.arguments.contains("-STOKEStorageBridgeEnabled") ||
            processInfo.environment["STOKE_STORAGE_BRIDGE_ENABLED"] == "1"
        let adsBridgeEnabled = processInfo.arguments.contains("-STOKEAdMobBridgeEnabled") ||
            processInfo.environment["STOKE_ADMOB_BRIDGE_ENABLED"] == "1"
        let purchasesBridgeEnabled = processInfo.arguments.contains("-STOKEPurchasesBridgeEnabled") ||
            processInfo.environment["STOKE_PURCHASES_BRIDGE_ENABLED"] == "1"
        let mode: NativeBridgeMode
        if purchasesBridgeEnabled {
            mode = .storageAdsAndPurchases
        } else if adsBridgeEnabled {
            mode = .storageAndAds
        } else if storageBridgeEnabled {
            mode = .storageOnly
        } else {
            mode = .disabled
        }
        stokeBridgeLogger.notice("Default bridge mode selected: \(String(describing: mode), privacy: .public)")
        return mode
    }

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

private struct PreviewShellView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("STOKE")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
            Text("WebView disabled in Xcode Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct WebViewContainer: UIViewRepresentable {
    let htmlFileName: String
    let messageHandler: WebViewMessageHandler
    @Binding var webView: WKWebView?
    let bridgeMode: NativeBridgeMode
    var initialSkinEnabled: Bool = true
    var onPageLoaded: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(messageHandler: messageHandler)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        stokeBridgeLogger.notice("makeUIView begin bridgeMode=\(String(describing: bridgeMode), privacy: .public)")
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        Self.registerScriptMessageHandlers(
            for: bridgeMode,
            in: config.userContentController,
            coordinator: context.coordinator
        )
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        // .never lets viewport-fit=cover + CSS env(safe-area-inset-*) own all layout;
        // .automatic would double-shift content by adding its own content inset on top of CSS.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        let bridgeScript = Self.bridgeScript(for: bridgeMode)
        if !bridgeScript.isEmpty {
            let script = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
        }
        let skinScript = Self.blockBlastSkinScript(initialEnabled: initialSkinEnabled)
        if !skinScript.isEmpty {
            let style = WKUserScript(source: skinScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            config.userContentController.addUserScript(style)
        }
        
        messageHandler.webView = webView

        // Store SwiftUI binding reference after UIView creation settles.
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // Load HTML file
        if let htmlPath = Bundle.main.path(forResource: htmlFileName, ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            let baseURL = URL(fileURLWithPath: htmlPath)
            stokeBridgeLogger.notice("Loading bundled HTML \(htmlFileName, privacy: .public).html bridgeMode=\(String(describing: bridgeMode), privacy: .public)")
            webView.loadHTMLString(htmlString, baseURL: baseURL)
        } else {
            stokeBridgeLogger.error("Failed to load bundled HTML \(htmlFileName, privacy: .public).html")
        }
        
        stokeBridgeLogger.notice("makeUIView end bridgeMode=\(String(describing: bridgeMode), privacy: .public)")
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPageLoaded = onPageLoaded
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        stokeBridgeLogger.notice("dismantleUIView begin")
        removeScriptMessageHandlers(from: uiView.configuration.userContentController)
        uiView.navigationDelegate = nil
        coordinator.messageHandler.webView = nil
        stokeBridgeLogger.notice("dismantleUIView end")
    }

    private static func registerScriptMessageHandlers(
        for mode: NativeBridgeMode,
        in userContentController: WKUserContentController,
        coordinator: Coordinator
    ) {
        stokeBridgeLogger.notice("Register script message handlers for mode=\(String(describing: mode), privacy: .public)")
        removeScriptMessageHandlers(from: userContentController)

        if mode.includesStorage {
            stokeBridgeLogger.notice("Adding storage script message handler")
            userContentController.add(WeakScriptMessageHandler(coordinator), name: "storage")
        }
        if mode.includesAdMob {
            stokeBridgeLogger.notice("Adding AdMob script message handler")
            userContentController.add(WeakScriptMessageHandler(coordinator), name: "admobAction")
        }
        if mode.includesPurchases {
            stokeBridgeLogger.notice("Adding purchase script message handler")
            userContentController.add(WeakScriptMessageHandler(coordinator), name: "purchaseAction")
        }
    }

    private static func removeScriptMessageHandlers(from userContentController: WKUserContentController) {
        ["storage", "admobAction", "purchaseAction"].forEach {
            stokeBridgeLogger.notice("Removing script message handler \($0, privacy: .public)")
            userContentController.removeScriptMessageHandler(forName: $0)
        }
    }

    private static func bridgeScript(for mode: NativeBridgeMode) -> String {
        var scripts: [String] = []

        if mode.includesStorage {
            scripts.append("""
            (function () {
                let nextStorageRequestID = 1;
                const STORAGE_TIMEOUT_MS = 1200;

                function postNative(handlerName, payload) {
                    try {
                        const target = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName];
                        if (!target) return false;
                        target.postMessage(JSON.stringify(payload || {}));
                        return true;
                    } catch (error) {
                        console.warn('Native bridge post failed', handlerName, error);
                        return false;
                    }
                }

                function fallbackGet(storageKey) {
                    try {
                        const value = localStorage.getItem(storageKey);
                        return value ? { value } : {};
                    } catch (error) {
                        return {};
                    }
                }

                function fallbackSet(storageKey, value) {
                    try { localStorage.setItem(storageKey, value); } catch (error) {}
                }

                window.storage = {
                    get: (key) => {
                        return new Promise((resolve) => {
                            const storageKey = String(key || '');
                            if (!storageKey) { resolve({}); return; }

                            const requestID = String(nextStorageRequestID++);
                            window.storageCallbacks = window.storageCallbacks || {};
                            const timeout = setTimeout(() => {
                                if (!window.storageCallbacks || !window.storageCallbacks[requestID]) return;
                                delete window.storageCallbacks[requestID];
                                resolve(fallbackGet(storageKey));
                            }, STORAGE_TIMEOUT_MS);

                            window.storageCallbacks[requestID] = (result) => {
                                clearTimeout(timeout);
                                delete window.storageCallbacks[requestID];
                                if (result && typeof result.value === 'string') {
                                    resolve(result);
                                } else {
                                    resolve(fallbackGet(storageKey));
                                }
                            };

                            if (!postNative('storage', { action: 'get', key: storageKey, requestID })) {
                                clearTimeout(timeout);
                                delete window.storageCallbacks[requestID];
                                resolve(fallbackGet(storageKey));
                            }
                        });
                    },
                    set: (key, value) => {
                        const storageKey = String(key || '');
                        if (!storageKey) return Promise.resolve();
                        const storageValue = String(value || '');
                        fallbackSet(storageKey, storageValue);
                        postNative('storage', { action: 'set', key: storageKey, value: storageValue });
                        return Promise.resolve();
                    }
                };
            })();
            """)
        }

        if mode.includesAdMob || mode.includesPurchases {
            scripts.append("""
            (function () {
                window.Capacitor = {
                    isNativePlatform: () => true,
                    Plugins: window.Capacitor?.Plugins || {}
                };
            })();
            """)
        }

        if mode.includesAdMob {
            scripts.append("""
            (function () {
                function postNative(handlerName, payload) {
                    try {
                        const target = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName];
                        if (!target) return false;
                        target.postMessage(JSON.stringify(payload || {}));
                        return true;
                    } catch (error) {
                        console.warn('Native bridge post failed', handlerName, error);
                        return false;
                    }
                }

                window.Capacitor.Plugins.AdMob = {
                    initialize: () => Promise.resolve(postNative('admobAction', { action: 'initialize' })),
                    showBanner: (options) => Promise.resolve(postNative('admobAction', { action: 'showBanner', options })),
                    removeBanner: () => Promise.resolve(postNative('admobAction', { action: 'removeBanner' })),
                    prepareInterstitial: (options) => Promise.resolve(postNative('admobAction', { action: 'prepareInterstitial', options })),
                    showInterstitial: () => Promise.resolve(postNative('admobAction', { action: 'showInterstitial' })),
                    prepareRewardVideoAd: (options) => Promise.resolve(postNative('admobAction', { action: 'prepareRewardVideoAd', options })),
                    showRewardVideoAd: () => new Promise((resolve, reject) => {
                        window.rewardedAdCallbacks = { resolve, reject };
                        if (!postNative('admobAction', { action: 'showRewardVideoAd' })) reject(new Error('Ad bridge unavailable'));
                    }),
                    addListener: (eventName, callback) => {
                        window.admobListeners = window.admobListeners || {};
                        window.admobListeners[eventName] = callback;
                    }
                };
            })();
            """)
        }

        if mode.includesPurchases {
            scripts.append("""
            (function () {
                function postNative(handlerName, payload) {
                    try {
                        const target = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName];
                        if (!target) return false;
                        target.postMessage(JSON.stringify(payload || {}));
                        return true;
                    } catch (error) {
                        console.warn('Native bridge post failed', handlerName, error);
                        return false;
                    }
                }

                window.Capacitor.Plugins.Purchases = {
                    configure: () => Promise.resolve(postNative('purchaseAction', { action: 'configure' })),
                    getOfferings: () => new Promise((resolve, reject) => {
                        window.offeringsCallback = resolve;
                        window.offeringsErrorCallback = reject;
                        if (!postNative('purchaseAction', { action: 'getOfferings' })) reject(new Error('Purchases bridge unavailable'));
                    }),
                    purchasePackage: (options) => new Promise((resolve, reject) => {
                        const packageId = options && options.aPackage && options.aPackage.identifier;
                        if (!packageId) { reject(new Error('Missing package identifier')); return; }
                        window.purchaseCallbacks = { resolve, reject };
                        if (!postNative('purchaseAction', { action: 'purchasePackage', packageId })) reject(new Error('Purchases bridge unavailable'));
                    })
                };
            })();
            """)
        }

        return scripts.joined(separator: "\n")
    }
    
    private static func blockBlastSkinScript(initialEnabled: Bool = true) -> String {
        return """
        (function() {
          var BOARD_SIZE = 8;
          window.__skinEnabled = \(initialEnabled ? "true" : "false");

          function applyCanvasFilter(canvas) {
            try {
              canvas.style.filter = 'drop-shadow(0 3px 0 rgba(255,255,255,0.22)) drop-shadow(0 1px 0 rgba(255,255,255,0.12)) drop-shadow(0 14px 22px rgba(0,0,0,0.60)) saturate(1.22) contrast(1.10)';
              canvas.style.webkitFilter = canvas.style.filter;
            } catch (e) {}
          }

          function ensureGlossOverlay(rect) {
            let overlay = document.getElementById('ios-gloss-overlay');
            if (!overlay) {
              overlay = document.createElement('div');
              overlay.id = 'ios-gloss-overlay';
              overlay.style.position = 'fixed';
              overlay.style.pointerEvents = 'none';
              overlay.style.zIndex = '9999';
              overlay.style.mixBlendMode = 'screen';
              overlay.style.display = window.__skinEnabled ? '' : 'none';
              document.body.appendChild(overlay);
            }
            overlay.style.left = rect.left + 'px';
            overlay.style.top = rect.top + 'px';
            overlay.style.width = rect.width + 'px';
            overlay.style.height = rect.height + 'px';
            overlay.style.borderRadius = '18px';
            overlay.style.backgroundImage =
              'linear-gradient(to bottom, rgba(255,255,255,0.38), rgba(255,255,255,0.18) 38%, rgba(255,255,255,0.05) 58%, rgba(0,0,0,0.26)), ' +
              'radial-gradient(circle at 28% 0%, rgba(255,255,255,0.38), rgba(255,255,255,0) 42%), ' +
              'radial-gradient(circle at 72% 6%, rgba(255,255,255,0.22), rgba(255,255,255,0) 46%)';
            overlay.style.backgroundRepeat = 'no-repeat';
          }

          function ensureBevelGridOverlay(rect) {
            let overlay = document.getElementById('ios-bevel-grid');
            if (!overlay) {
              overlay = document.createElement('div');
              overlay.id = 'ios-bevel-grid';
              overlay.style.position = 'fixed';
              overlay.style.pointerEvents = 'none';
              overlay.style.zIndex = '9998';
              overlay.style.mixBlendMode = 'overlay';
              overlay.style.opacity = '0.50';
              overlay.style.display = window.__skinEnabled ? '' : 'none';
              document.body.appendChild(overlay);
            }
            overlay.style.left = rect.left + 'px';
            overlay.style.top = rect.top + 'px';
            overlay.style.width = rect.width + 'px';
            overlay.style.height = rect.height + 'px';
            overlay.style.borderRadius = '18px';
            overlay.style.boxShadow = 'inset 0 1px 0 rgba(255,255,255,0.18), inset 0 -2px 8px rgba(0,0,0,0.28)';

            var tileW = (rect.width / BOARD_SIZE);
            var tileH = (rect.height / BOARD_SIZE);
            overlay.style.backgroundSize = tileW + 'px ' + tileH + 'px';
            overlay.style.backgroundRepeat = 'repeat';
            overlay.style.backgroundImage =
              'conic-gradient(from -90deg, ' +
                'rgba(255,255,255,0.36) 0 28deg, ' +
                'rgba(0,0,0,0.22) 28deg 144deg, ' +
                'rgba(0,0,0,0.38) 144deg 216deg, ' +
                'rgba(255,255,255,0.14) 216deg 332deg, ' +
                'rgba(255,255,255,0.36) 332deg 360deg)';
          }

          function update() {
            if (!window.__skinEnabled) return;
            const canvas = document.querySelector('canvas');
            if (!canvas) return;
            applyCanvasFilter(canvas);
            const rect = canvas.getBoundingClientRect();
            ensureGlossOverlay(rect);
            ensureBevelGridOverlay(rect);
          }

          // RAF debounce: coalesce rapid DOM mutations into one update per frame
          var _rafPending = false;
          function scheduleUpdate() {
            if (_rafPending) return;
            _rafPending = true;
            requestAnimationFrame(function() { _rafPending = false; update(); });
          }

          const obs = new MutationObserver(scheduleUpdate);
          obs.observe(document.documentElement, { childList: true, subtree: true });
          window.addEventListener('resize', scheduleUpdate);

          document.addEventListener('DOMContentLoaded', update);
          setTimeout(update, 0);
          setTimeout(update, 250);
          setTimeout(update, 1000);
        })();
        """
    }
    
    private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?

        init(_ target: WKScriptMessageHandler) {
            self.target = target
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let target else {
                stokeBridgeLogger.error("Dropping script message \(message.name, privacy: .public): target deallocated")
                return
            }
            target.userContentController(userContentController, didReceive: message)
        }
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let messageHandler: WebViewMessageHandler
        var onPageLoaded: (() -> Void)?

        init(messageHandler: WebViewMessageHandler) {
            self.messageHandler = messageHandler
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            stokeBridgeLogger.notice("WKWebView didFinish navigation")
            onPageLoaded?()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            stokeBridgeLogger.notice("Received script message \(message.name, privacy: .public)")
            guard let body = Self.messageBodyDictionary(message.body) else {
                stokeBridgeLogger.error("Invalid script message body for \(message.name, privacy: .public)")
                return
            }
            
            switch message.name {
            case "storage":
                messageHandler.handleStorageMessage(body)
            case "admobAction":
                messageHandler.handleAdMobMessage(body)
            case "purchaseAction":
                messageHandler.handlePurchasesMessage(body)
            default:
                break
            }
        }
        
        private static func messageBodyDictionary(_ body: Any) -> [String: Any]? {
            if let dictionary = body as? [String: Any] {
                return dictionary
            }
            
            if let json = body as? String {
                return dictionary(fromJSON: json)
            }
            
            return nil
        }
        
        private static func dictionary(fromJSON json: String) -> [String: Any]? {
            guard let data = json.data(using: .utf8) else { return nil }
            
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                return object as? [String: Any]
            } catch {
                return nil
            }
        }
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

        let slotFrame = bannerSlotFrame(from: options, in: hostView)
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
        let bannerVerticalOffset: CGFloat = 50
        let centerX = slotFrame?.midX ?? hostView.bounds.midX
        let centerY = (slotFrame?.midY ?? (hostView.safeAreaInsets.top + 93)) + bannerVerticalOffset
        bannerConstraints = [
            banner.centerXAnchor.constraint(equalTo: hostView.leadingAnchor, constant: centerX),
            banner.centerYAnchor.constraint(equalTo: hostView.topAnchor, constant: centerY)
        ]
        NSLayoutConstraint.activate(bannerConstraints)

        bannerView = banner
        banner.load(Request())
        stokeBridgeLogger.notice("Requested banner ad at x=\(centerX, privacy: .public) y=\(centerY, privacy: .public)")
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
        guard let adUnitID = options?["adId"] as? String, !adUnitID.isEmpty else {
            return fallback
        }
        return adUnitID
    }

    private func bannerSlotFrame(from options: [String: Any]?, in hostView: UIView) -> CGRect? {
        guard let frame = options?["adBannerFrame"] as? [String: Any],
              let x = frame["x"] as? Double,
              let y = frame["y"] as? Double,
              let width = frame["width"] as? Double,
              let height = frame["height"] as? Double,
              width > 0,
              height > 0 else {
            return nil
        }
        return CGRect(
            x: CGFloat(x),
            y: CGFloat(y),
            width: min(CGFloat(width), hostView.bounds.width),
            height: CGFloat(height)
        )
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

// MARK: - WebView Message Handler

class WebViewMessageHandler: ObservableObject {
    weak var webView: WKWebView?
    private var observerTokens: [NSObjectProtocol] = []
    
    init() {
        setupNotifications()
    }
    
    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }
    
    private func setupNotifications() {
        // Rewarded ad notifications are still backed by the placeholder ad bridge.
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .rewardedAdEarned,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.admobListeners?.onRewardedVideoAdReward) { window.admobListeners.onRewardedVideoAdReward(); }")
            self?.evaluateJS("if (window.rewardedAdCallbacks?.resolve) { window.rewardedAdCallbacks.resolve(); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .rewardedAdFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.rewardedAdCallbacks?.reject) { window.rewardedAdCallbacks.reject(new Error('Ad failed to load')); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .offeringsLoaded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let offerings = notification.object as? Offerings else { return }
            let packagesJSON = self?.offeringsToJSON(offerings) ?? "{}"
            self?.evaluateJS("if (window.offeringsCallback) { window.offeringsCallback(\(packagesJSON)); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .offeringsFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.offeringsErrorCallback) { window.offeringsErrorCallback(new Error('Offerings unavailable')); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .purchaseSuccess,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.purchaseCallbacks?.resolve) { window.purchaseCallbacks.resolve(); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .purchaseFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.purchaseCallbacks?.reject) { window.purchaseCallbacks.reject(new Error('Purchase failed')); }")
        })
        
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .purchaseCancelled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.purchaseCallbacks?.reject) { window.purchaseCallbacks.reject(new Error('User cancelled')); }")
        })
    }
    
    func handleStorageMessage(_ body: [String: Any]) {
        guard let action = body["action"] as? String,
              let key = body["key"] as? String else { return }

        switch action {
        case "get":
            guard let requestID = body["requestID"] as? String else {
                stokeBridgeLogger.error("Storage get missing requestID for key=\(key, privacy: .public)")
                return
            }
            stokeBridgeLogger.notice("Storage get key=\(key, privacy: .public) requestID=\(requestID, privacy: .public)")
            let value = UserDefaults.standard.string(forKey: key)
            let response = value != nil ? ["value": value!] : [:]
            let jsonString = toJSON(response)
            let requestIDLiteral = jsStringLiteral(requestID)
            evaluateJS("if (window.storageCallbacks?.[\(requestIDLiteral)]) { window.storageCallbacks[\(requestIDLiteral)](\(jsonString)); }")
        case "set":
            if let value = body["value"] as? String {
                stokeBridgeLogger.notice("Storage set key=\(key, privacy: .public) bytes=\(value.utf8.count, privacy: .public)")
                UserDefaults.standard.set(value, forKey: key)
                UserDefaults.standard.synchronize()
            } else {
                stokeBridgeLogger.error("Storage set missing value for key=\(key, privacy: .public)")
            }
        default:
            break
        }
    }
    
    func handleAdMobMessage(_ body: [String: Any]) {
        NativeAdMobBridge.shared.handle(body)
    }
    
    func handlePurchasesMessage(_ body: [String: Any]) {
        NotificationCenter.default.post(name: .purchaseAction, object: body)
    }
    
    func evaluateJS(_ script: String) {
        guard let webView else {
            stokeBridgeLogger.error("Skipping evaluateJS because webView is nil")
            return
        }
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                stokeBridgeLogger.error("JS evaluation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func toJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    private func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }
    
    private func offeringsToJSON(_ offerings: Offerings) -> String {
        guard let current = offerings.current else { return "{\"offerings\": {}}" }
        
        var packagesArray: [[String: Any]] = []
        for package in current.availablePackages {
            packagesArray.append([
                "identifier": package.identifier,
                "product": [
                    "priceString": package.storeProduct.localizedPriceString
                ]
            ])
        }
        
        let result: [String: Any] = [
            "offerings": [
                "current": [
                    "availablePackages": packagesArray
                ]
            ]
        ]
        
        return toJSON(result)
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
