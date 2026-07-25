//
//  PurchaseManager.swift
//  blocks
//
//  Created by Owner on 7/25/26.
//

import Foundation
import Combine
import RevenueCat

class PurchaseManager: NSObject {
    static let shared = PurchaseManager()
    
    // Test API key from the HTML file
    // Replace with production key: appl_... when ready
    private let apiKey = "test_TikeKfmfcUbcOAEWUZyfPOTKgUc"
    
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
        Purchases.logLevel = .debug
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
                NotificationCenter.default.post(
                    name: .offeringsLoaded,
                    object: offerings
                )
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

extension Notification.Name {
    static let purchaseAction = Notification.Name("purchaseAction")
    static let offeringsLoaded = Notification.Name("offeringsLoaded")
    static let purchaseSuccess = Notification.Name("purchaseSuccess")
    static let purchaseFailed = Notification.Name("purchaseFailed")
    static let purchaseCancelled = Notification.Name("purchaseCancelled")
}
