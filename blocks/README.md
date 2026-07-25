# STOKE - iOS Game

A native iOS implementation of the STOKE puzzle game, featuring AdMob monetization and RevenueCat in-app purchases.

## 🎮 Game Overview

STOKE is a strategic block-placement puzzle game where players:
- Place colored pieces on an 8×8 grid
- Clear lines to build heat multipliers
- Reach max heat to trigger JACKPOT bombs
- Earn coins through gameplay
- Complete daily objectives
- Maintain daily streaks

## 📱 Features

### Core Gameplay
- ✅ Dynamic piece generation with difficulty scaling
- ✅ Heat multiplier system (up to 4×)
- ✅ Gold/wild gems for bonus points
- ✅ Jackpot board clears
- ✅ Daily objectives with coin rewards
- ✅ Streak tracking with freeze system

### Monetization
- ✅ AdMob banner ads (bottom)
- ✅ Interstitial ads (every 3 games)
- ✅ Rewarded video ads (continue after game over)
- ✅ In-app purchases (coin packs via RevenueCat)

### Technical
- ✅ Native SwiftUI + WebKit wrapper
- ✅ JavaScript ↔ Native bridge
- ✅ Persistent storage (UserDefaults)
- ✅ Audio engine with procedural music
- ✅ Social sharing (jackpot cards)

## 🛠 Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 15.0+ deployment target
- CocoaPods or Swift Package Manager

### Installation

1. **Clone/Open the project**
   ```bash
   open blocks.xcodeproj
   ```

2. **Add dependencies** (choose one method):

   **Option A: Swift Package Manager (recommended)**
   - File → Add Package Dependencies
   - Add: `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
   - Add: `https://github.com/RevenueCat/purchases-ios.git`

   **Option B: CocoaPods**
   ```bash
   pod install
   open blocks.xcworkspace
   ```

3. **Add stoke.html to project**
   - Drag `stoke.html` into Xcode
   - ✅ Copy items if needed
   - ✅ Add to targets: blocks

4. **Update Info.plist**
   - Copy settings from `Info-Template.plist`
   - Or merge manually (see SETUP.md)

5. **Build & Run**
   - Select target device
   - ⌘R to build and run

## 📂 Project Structure

```
blocks/
├── blocksApp.swift          # App entry point
├── ContentView.swift        # Main UI + WebView + message handler
├── AdMobManager.swift       # AdMob SDK integration
├── PurchaseManager.swift    # RevenueCat integration
├── WebView.swift           # (deprecated - merged into ContentView)
├── stoke.html              # Game HTML/React/JavaScript
├── Info-Template.plist     # Info.plist configuration template
├── SETUP.md               # Detailed setup instructions
└── README.md              # This file
```

## 🔧 Configuration

### AdMob Setup

Ad unit IDs are pre-configured:
```
App ID: ca-app-pub-7262617456411456~5433417356
Banner: ca-app-pub-7262617456411456/9508273591
Interstitial: ca-app-pub-7262617456411456/6307395181
Rewarded: ca-app-pub-7262617456411456/7812048544
```

For testing, add your device ID in `AdMobManager.swift`:
```swift
GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["YOUR_DEVICE_ID"]
```

### RevenueCat Setup

1. Create account at https://www.revenuecat.com
2. Set up 4 products in App Store Connect:
   - `coins_100` ($0.99 → 100 coins)
   - `coins_350` ($2.99 → 350 coins)
   - `coins_800` ($4.99 → 800 coins)
   - `coins_2000` ($9.99 → 2000 coins)
3. Replace test key in `PurchaseManager.swift`:
   ```swift
   private let apiKey = "appl_YOUR_PRODUCTION_KEY"
   ```

## 🎯 How the Bridge Works

The app uses a JavaScript ↔ Swift bridge to connect the HTML game with native iOS features:

### Storage Bridge
```javascript
// JavaScript
await window.storage.set("key", "value");
const data = await window.storage.get("key");
```
```swift
// Swift (handled automatically)
UserDefaults.standard.set(value, forKey: key)
```

### Ad Bridge
```javascript
// JavaScript
await window.Capacitor.Plugins.AdMob.showBanner();
await window.Capacitor.Plugins.AdMob.showRewardVideoAd();
```
```swift
// Swift
AdMobManager.shared.showBanner()
AdMobManager.shared.showRewardedAd()
```

### Purchase Bridge
```javascript
// JavaScript
const offerings = await window.Capacitor.Plugins.Purchases.getOfferings();
await window.Capacitor.Plugins.Purchases.purchasePackage({ aPackage });
```
```swift
// Swift
PurchaseManager.shared.fetchOfferings()
PurchaseManager.shared.purchasePackage()
```

## 🧪 Testing

### Test Ads
1. Run on a real device (simulator doesn't show real ads)
2. Use test device IDs during development
3. Check Xcode console for ad loading status

### Test Purchases
1. Create sandbox tester in App Store Connect
2. Sign out of iTunes in Settings
3. Run app and make purchase
4. Sign in with sandbox account when prompted

### Debug WebView
1. Run app on device
2. Open Safari → Develop → [Your Device] → [App Name]
3. Access full JavaScript console

## 📋 Pre-Production Checklist

- [ ] Replace RevenueCat test key with production key
- [ ] Remove test device IDs from AdMob configuration
- [ ] Add privacy policy URL to App Store listing
- [ ] Configure App Tracking Transparency messaging
- [ ] Test all ad placements on real device
- [ ] Test all purchase flows in sandbox
- [ ] Verify daily objectives reset properly
- [ ] Test streak system over multiple days
- [ ] Review and optimize ad frequency
- [ ] Add analytics (optional)

## 🐛 Troubleshooting

### "Ad failed to load"
- Verify Info.plist has `GADApplicationIdentifier`
- Check ad unit IDs match AdMob console
- Ensure running on real device (not simulator)
- Check console for specific error messages

### "Purchase failed"
- Verify products exist in App Store Connect
- Ensure sandbox tester is signed in
- Check RevenueCat API key is correct
- Review console for RevenueCat errors

### "Blank screen"
- Verify `stoke.html` is in app bundle (Build Phases → Copy Bundle Resources)
- Check Safari web inspector for JavaScript errors
- Ensure HTML file loads in Safari first

### "Storage not persisting"
- Data is stored in UserDefaults with key `"stoke-save"`
- Check app isn't being reinstalled (clears data)
- Verify JavaScript calls `window.storage.set()` correctly

## 📚 Resources

- [AdMob iOS Guide](https://developers.google.com/admob/ios)
- [RevenueCat Documentation](https://docs.revenuecat.com)
- [WebKit JavaScript Bridge](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler)
- [App Store Connect](https://appstoreconnect.apple.com)

## 📄 License

All rights reserved. This is proprietary software for the STOKE game.

## 🤝 Support

For technical issues:
1. Check SETUP.md for detailed configuration
2. Review Xcode console for error messages
3. Use Safari web inspector for JavaScript debugging
4. Check AdMob and RevenueCat dashboards for SDK issues

---

**Built with:** Swift, SwiftUI, WebKit, AdMob, RevenueCat, React
**Platforms:** iOS 15.0+
**Version:** 1.0.0
