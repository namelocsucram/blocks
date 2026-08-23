//
//  blocksApp.swift
//  blocks
//
//  Created by Owner on 7/25/26.
//

import SwiftUI
import AVFoundation
import AppTrackingTransparency

@main
struct blocksApp: App {
    init() {
        // Keep WebAudio audible in the native shell, even when the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        requestTrackingAuthorizationIfNeeded()
        validateLaunchConfiguration()

        // Initialize RevenueCat
        PurchaseManager.shared.configure()
    }

    private func requestTrackingAuthorizationIfNeeded() {
        guard #available(iOS 14, *),
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    private func validateLaunchConfiguration() {
        let defaults = Bundle.main

        if (defaults.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String)?.isEmpty != false {
            NotificationCenter.default.post(
                name: .adMobConfigurationWarning,
                object: "AdMob not configured: add GADApplicationIdentifier to the app Info.plist."
            )
        }

        if (defaults.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String)?.isEmpty != false {
            NotificationCenter.default.post(
                name: .adMobConfigurationWarning,
                object: "AdMob consent not configured: add NSUserTrackingUsageDescription to the app Info.plist."
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
