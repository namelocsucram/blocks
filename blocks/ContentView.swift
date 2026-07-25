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
            
            WebViewContainer(
                htmlFileName: "index",
                messageHandler: messageHandler,
                webView: $webView
            )
            .ignoresSafeArea()
        }
        .onAppear {
            // Initialize RevenueCat
            PurchaseManager.shared.configure()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

struct WebViewContainer: UIViewRepresentable {
    let htmlFileName: String
    let messageHandler: WebViewMessageHandler
    @Binding var webView: WKWebView?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(messageHandler: messageHandler)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        // Add message handlers for JavaScript bridge
        config.userContentController.add(context.coordinator, name: "storage")
        config.userContentController.add(context.coordinator, name: "admobAction")
        config.userContentController.add(context.coordinator, name: "purchaseAction")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // Inject native bridge script
        let bridgeScript = """
        window.Capacitor = {
            isNativePlatform: () => true,
            Plugins: {}
        };
        
        // AdMob bridge
        window.Capacitor.Plugins.AdMob = {
            initialize: () => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'initialize' });
                return Promise.resolve();
            },
            showBanner: (options) => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'showBanner', options });
                return Promise.resolve();
            },
            removeBanner: () => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'removeBanner' });
                return Promise.resolve();
            },
            prepareInterstitial: (options) => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'prepareInterstitial', options });
                return Promise.resolve();
            },
            showInterstitial: () => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'showInterstitial' });
                return Promise.resolve();
            },
            prepareRewardVideoAd: (options) => {
                webkit.messageHandlers.admobAction.postMessage({ action: 'prepareRewardVideoAd', options });
                return Promise.resolve();
            },
            showRewardVideoAd: () => {
                return new Promise((resolve, reject) => {
                    window.rewardedAdCallbacks = { resolve, reject };
                    webkit.messageHandlers.admobAction.postMessage({ action: 'showRewardVideoAd' });
                });
            },
            addListener: (eventName, callback) => {
                window.admobListeners = window.admobListeners || {};
                window.admobListeners[eventName] = callback;
            }
        };
        
        // RevenueCat bridge
        window.Capacitor.Plugins.Purchases = {
            configure: (options) => {
                webkit.messageHandlers.purchaseAction.postMessage({ action: 'configure', options });
                return Promise.resolve();
            },
            getOfferings: () => {
                return new Promise((resolve) => {
                    window.offeringsCallback = resolve;
                    webkit.messageHandlers.purchaseAction.postMessage({ action: 'getOfferings' });
                });
            },
            purchasePackage: (options) => {
                return new Promise((resolve, reject) => {
                    window.purchaseCallbacks = { resolve, reject };
                    webkit.messageHandlers.purchaseAction.postMessage({ 
                        action: 'purchasePackage', 
                        packageId: options.aPackage.identifier 
                    });
                });
            }
        };
        
        // Storage bridge
        window.storage = {
            get: (key) => {
                return new Promise((resolve) => {
                    window.storageCallbacks = window.storageCallbacks || {};
                    window.storageCallbacks[key] = resolve;
                    webkit.messageHandlers.storage.postMessage({ action: 'get', key });
                });
            },
            set: (key, value) => {
                webkit.messageHandlers.storage.postMessage({ action: 'set', key, value });
                return Promise.resolve();
            }
        };
        """
        
        let script = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        
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
            guard let body = message.body as? [String: Any] else { return }
            
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
    }
}

// MARK: - WebView Message Handler

class WebViewMessageHandler: ObservableObject {
    weak var webView: WKWebView?
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Rewarded ad notifications - stubbed for now
        // TODO: Implement actual AdMob integration
        NotificationCenter.default.addObserver(
            forName: .rewardedAdEarned,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.admobListeners?.onRewardedVideoAdReward) { window.admobListeners.onRewardedVideoAdReward(); }")
            self?.evaluateJS("if (window.rewardedAdCallbacks?.resolve) { window.rewardedAdCallbacks.resolve(); }")
        }
        
        NotificationCenter.default.addObserver(
            forName: .rewardedAdFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.rewardedAdCallbacks?.reject) { window.rewardedAdCallbacks.reject(new Error('Ad failed to load')); }")
        }
        
        // Purchase notifications
        NotificationCenter.default.addObserver(
            forName: .offeringsLoaded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let offerings = notification.object as? Offerings else { return }
            let packagesJSON = self?.offeringsToJSON(offerings) ?? "{}"
            self?.evaluateJS("if (window.offeringsCallback) { window.offeringsCallback(\(packagesJSON)); }")
        }
        
        NotificationCenter.default.addObserver(
            forName: .purchaseSuccess,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.evaluateJS("if (window.purchaseCallbacks?.resolve) { window.purchaseCallbacks.resolve(); }")
        }
        
        NotificationCenter.default.addObserver(
            forName: .purchaseFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.purchaseCallbacks?.reject) { window.purchaseCallbacks.reject(new Error('Purchase failed')); }")
        }
        
        NotificationCenter.default.addObserver(
            forName: .purchaseCancelled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateJS("if (window.purchaseCallbacks?.reject) { window.purchaseCallbacks.reject(new Error('User cancelled')); }")
        }
    }
    
    func handleStorageMessage(_ body: [String: Any]) {
        guard let action = body["action"] as? String,
              let key = body["key"] as? String else { return }
        
        switch action {
        case "get":
            let value = UserDefaults.standard.string(forKey: key)
            let response = value != nil ? ["value": value!] : [:]
            let jsonString = toJSON(response)
            evaluateJS("if (window.storageCallbacks?.['\(key)']) { window.storageCallbacks['\(key)'](\(jsonString)); }")
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
