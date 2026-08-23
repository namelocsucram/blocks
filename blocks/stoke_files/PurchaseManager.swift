//
//  PurchaseManager.swift
//  blocks
//
//  Created by Owner on 7/25/26.
//

import Foundation
import RevenueCat

class PurchaseManager: NSObject {
    static let shared = PurchaseManager()
    
    // Read the public RevenueCat SDK key from the app bundle so release builds
    // can be configured without hardcoding secrets in source.
    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
    
    var offerings: Offerings?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePurchaseAction(_:)),
            name: .purchaseAction,
            object: nil
        )
    }
    
    func configure() {
        guard !Purchases.isConfigured else { return }
        guard !apiKey.isEmpty else {
            let message = "RevenueCat not configured: add RevenueCatAPIKey to the app Info.plist."
            print(message)
            NotificationCenter.default.post(name: .revenueCatConfigurationWarning, object: message)
            return
        }
        #if !DEBUG
        guard apiKey.hasPrefix("appl_") else {
            let message = "RevenueCat skipped: release builds require a production public API key starting with appl_."
            print(message)
            NotificationCenter.default.post(name: .revenueCatConfigurationWarning, object: message)
            return
        }
        #endif
        
        Purchases.configure(withAPIKey: apiKey)
    }
    
    @objc private func handlePurchaseAction(_ notification: Notification) {
        guard let body = notification.object as? [String: Any],
              let action = body["action"] as? String else { return }
        
        switch action {
        case "configure":
            configure()
        case "getOfferings":
            fetchOfferings { offerings in
                if let offerings {
                    NotificationCenter.default.post(
                        name: .offeringsLoaded,
                        object: offerings
                    )
                } else {
                    NotificationCenter.default.post(name: .offeringsFailed, object: nil)
                }
            }
        case "purchasePackage":
            if let packageId = body["packageId"] as? String {
                purchasePackage(identifier: packageId)
            }
        default:
            break
        }
    }
    
    func fetchOfferings(completion: @escaping (Offerings?) -> Void) {
        guard Purchases.isConfigured else {
            print("Cannot fetch offerings: RevenueCat is not configured.")
            completion(nil)
            return
        }
        
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("Failed to fetch offerings: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            self.offerings = offerings
            completion(offerings)
        }
    }
    
    func purchasePackage(identifier: String, completion: ((Bool) -> Void)? = nil) {
        guard Purchases.isConfigured else {
            print("Cannot purchase package: RevenueCat is not configured.")
            completion?(false)
            NotificationCenter.default.post(
                name: .purchaseFailed,
                object: PurchaseManagerError.notConfigured
            )
            return
        }
        
        guard let offerings = offerings,
              let package = offerings.current?.availablePackages.first(where: { $0.identifier == identifier }) else {
            print("Package not found: \(identifier)")
            completion?(false)
            NotificationCenter.default.post(name: .purchaseFailed, object: nil)
            return
        }
        
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            if let error = error {
                print("Purchase failed: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .purchaseFailed, object: error)
                completion?(false)
                return
            }
            
            if userCancelled {
                print("Purchase cancelled by user")
                NotificationCenter.default.post(name: .purchaseCancelled, object: nil)
                completion?(false)
                return
            }
            
            print("Purchase successful: \(identifier)")
            NotificationCenter.default.post(
                name: .purchaseSuccess,
                object: ["identifier": identifier]
            )
            completion?(true)
        }
    }
    
    func restorePurchases(completion: ((Bool) -> Void)? = nil) {
        guard Purchases.isConfigured else {
            print("Cannot restore purchases: RevenueCat is not configured.")
            completion?(false)
            return
        }
        
        Purchases.shared.restorePurchases { customerInfo, error in
            if let error = error {
                print("Restore failed: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            print("Restore successful")
            completion?(true)
        }
    }
}

enum PurchaseManagerError: Error {
    case notConfigured
}

extension Notification.Name {
    static let purchaseAction = Notification.Name("purchaseAction")
    static let offeringsLoaded = Notification.Name("offeringsLoaded")
    static let offeringsFailed = Notification.Name("offeringsFailed")
    static let purchaseSuccess = Notification.Name("purchaseSuccess")
    static let purchaseFailed = Notification.Name("purchaseFailed")
    static let purchaseCancelled = Notification.Name("purchaseCancelled")
    static let revenueCatConfigurationWarning = Notification.Name("revenueCatConfigurationWarning")
    static let adMobConfigurationWarning = Notification.Name("adMobConfigurationWarning")
}
