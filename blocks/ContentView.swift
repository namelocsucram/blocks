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
                    isNativeBridgeEnabled: false
                )
                .ignoresSafeArea()
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
    let isNativeBridgeEnabled: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(messageHandler: messageHandler)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if isNativeBridgeEnabled {
            config.userContentController.add(context.coordinator, name: "storage")
            config.userContentController.add(context.coordinator, name: "admobAction")
            config.userContentController.add(context.coordinator, name: "purchaseAction")
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        if isNativeBridgeEnabled {
            let bridgeScript = """
        function postNative(handlerName, payload) {
            try {
                const jsonPayload = JSON.stringify(payload || {});
                webkit.messageHandlers[handlerName].postMessage({ json: jsonPayload });
            } catch (error) {
                console.warn('Native bridge post failed', handlerName, error);
            }
        }
        
        window.Capacitor = {
            isNativePlatform: () => true,
            Plugins: {}
        };
        
        // AdMob bridge
        window.Capacitor.Plugins.AdMob = {
            initialize: () => {
                postNative('admobAction', { action: 'initialize' });
                return Promise.resolve();
            },
            showBanner: (options) => {
                postNative('admobAction', { action: 'showBanner', options });
                return Promise.resolve();
            },
            removeBanner: () => {
                postNative('admobAction', { action: 'removeBanner' });
                return Promise.resolve();
            },
            prepareInterstitial: (options) => {
                postNative('admobAction', { action: 'prepareInterstitial', options });
                return Promise.resolve();
            },
            showInterstitial: () => {
                postNative('admobAction', { action: 'showInterstitial' });
                return Promise.resolve();
            },
            prepareRewardVideoAd: (options) => {
                postNative('admobAction', { action: 'prepareRewardVideoAd', options });
                return Promise.resolve();
            },
            showRewardVideoAd: () => {
                return new Promise((resolve, reject) => {
                    window.rewardedAdCallbacks = { resolve, reject };
                    postNative('admobAction', { action: 'showRewardVideoAd' });
                });
            },
            addListener: (eventName, callback) => {
                window.admobListeners = window.admobListeners || {};
                window.admobListeners[eventName] = callback;
            }
        };
        
        // RevenueCat bridge
        window.Capacitor.Plugins.Purchases = {
            configure: () => {
                postNative('purchaseAction', { action: 'configure' });
                return Promise.resolve();
            },
            getOfferings: () => {
                return new Promise((resolve, reject) => {
                    window.offeringsCallback = resolve;
                    window.offeringsErrorCallback = reject;
                    postNative('purchaseAction', { action: 'getOfferings' });
                });
            },
            purchasePackage: (options) => {
                return new Promise((resolve, reject) => {
                    const packageId = options && options.aPackage && options.aPackage.identifier;
                    if (!packageId) {
                        reject(new Error('Missing package identifier'));
                        return;
                    }
                    window.purchaseCallbacks = { resolve, reject };
                    postNative('purchaseAction', { action: 'purchasePackage', packageId });
                });
            }
        };
        
        // Storage bridge
        window.storage = {
            get: (key) => {
                return new Promise((resolve) => {
                    window.storageCallbacks = window.storageCallbacks || {};
                    window.storageCallbacks[key] = resolve;
                    postNative('storage', { action: 'get', key });
                });
            },
            set: (key, value) => {
                postNative('storage', { action: 'set', key, value });
                return Promise.resolve();
            }
        };
        """
        
            let script = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
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
        // No updates needed
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let messageHandler: WebViewMessageHandler
        
        init(messageHandler: WebViewMessageHandler) {
            self.messageHandler = messageHandler
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
            if let envelope = body as? [String: Any],
               let json = envelope["json"] as? String {
                return dictionary(fromJSON: json)
            }
            
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
