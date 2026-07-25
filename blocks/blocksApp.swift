//
//  blocksApp.swift
//  blocks
//
//  Created by Owner on 7/25/26.
//

import SwiftUI

@main
struct blocksApp: App {
    init() {
        // Initialize RevenueCat
        PurchaseManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
