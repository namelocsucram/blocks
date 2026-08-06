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

enum NativeBridgeMode {
    case disabled
    case storageOnly
    case storageAndMonetization
    
    var includesStorage: Bool {
        switch self {
        case .storageOnly, .storageAndMonetization:
            return true
        case .disabled:
            return false
        }
    }
    
    var includesMonetization: Bool {
        switch self {
        case .storageAndMonetization:
            return true
        case .disabled, .storageOnly:
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
                    bridgeMode: .disabled
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
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if bridgeMode.includesStorage {
            config.userContentController.add(context.coordinator, name: "storage")
        }
        if bridgeMode.includesMonetization {
            config.userContentController.add(context.coordinator, name: "admobAction")
            config.userContentController.add(context.coordinator, name: "purchaseAction")
        }
        
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
        
        // Store reference
        DispatchQueue.main.async {
            self.webView = webView
            messageHandler.webView = webView
        }
        
        // Load HTML file
        if let htmlPath = Bundle.main.path(forResource: htmlFileName, ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            let baseURL = URL(fileURLWithPath: htmlPath)
            webView.loadHTMLString(htmlString, baseURL: baseURL)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPageLoaded = onPageLoaded
    }

    private static func bridgeScript(for mode: NativeBridgeMode) -> String {
        var scripts: [String] = []

        if mode.includesStorage {
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

                window.storage = {
                    get: (key) => {
                        return new Promise((resolve) => {
                            const storageKey = String(key || '');
                            if (!storageKey) { resolve({}); return; }
                            window.storageCallbacks = window.storageCallbacks || {};
                            window.storageCallbacks[storageKey] = resolve;
                            if (!postNative('storage', { action: 'get', key: storageKey })) resolve({});
                        });
                    },
                    set: (key, value) => {
                        const storageKey = String(key || '');
                        if (!storageKey) return Promise.resolve();
                        postNative('storage', { action: 'set', key: storageKey, value: String(value || '') });
                        return Promise.resolve();
                    }
                };
            })();
            """)
        }

        if mode.includesMonetization {
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

                window.Capacitor = {
                    isNativePlatform: () => true,
                    Plugins: window.Capacitor?.Plugins || {}
                };

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
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let messageHandler: WebViewMessageHandler
        var onPageLoaded: (() -> Void)?

        init(messageHandler: WebViewMessageHandler) {
            self.messageHandler = messageHandler
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onPageLoaded?()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = Self.messageBodyDictionary(message.body) else { return }
            
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
            let value = UserDefaults.standard.string(forKey: key)
            let response = value != nil ? ["value": value!] : [:]
            let jsonString = toJSON(response)
            let keyLiteral = jsStringLiteral(key)
            evaluateJS("if (window.storageCallbacks?.[\(keyLiteral)]) { window.storageCallbacks[\(keyLiteral)](\(jsonString)); }")
        case "set":
            if let value = body["value"] as? String {
                UserDefaults.standard.set(value, forKey: key)
            }
        default:
            break
        }
    }
    
    func handleAdMobMessage(_ body: [String: Any]) {
        // TODO: Integrate with existing AdMobManager or implement simple version
        print("AdMob action requested:", body)
        // NotificationCenter.default.post(name: .adMobAction, object: body)
    }
    
    func handlePurchasesMessage(_ body: [String: Any]) {
        NotificationCenter.default.post(name: .purchaseAction, object: body)
    }
    
    func evaluateJS(_ script: String) {
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("JS Error: \(error.localizedDescription)")
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
        guard let data = try? JSONSerialization.data(withJSONObject: value),
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
