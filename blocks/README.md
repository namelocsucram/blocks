# STOKE - iOS Game

A native iOS WebKit wrapper for the STOKE puzzle game, with production web bundling and native monetization code staged for AdMob and RevenueCat.

## Current Release Status

- The shipped game loads from bundled `index.html` generated from `stoke_files/stoke-app.jsx`.
- React and game code are built ahead of time with esbuild; shipped HTML does not depend on CDN React or runtime Babel.
- The native JavaScript bridge is currently disabled in `ContentView.swift` after simulator crashes in WebKit message handlers.
- Gameplay save data currently uses WebView `localStorage`, not native `UserDefaults`.
- AdMob and RevenueCat native handlers are not active until `NativeBridgeMode.storageAndMonetization` is safely re-enabled and tested on device.
- `PrivacyInfo.xcprivacy` is present for first-party app behavior; App Privacy labels still need final review against AdMob, UMP, RevenueCat, and the final bridge state.

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
- ⚠️ Browser/test placeholders for banner, interstitial, rewarded-rescue, and coin packs are present.
- ⚠️ Native AdMob and RevenueCat flows are staged but disabled with the native bridge.
- ⚠️ Production release still requires UMP consent, AdMob verification, RevenueCat production key, App Store Connect products, and sandbox testing.

### Technical
- ✅ Native SwiftUI + WebKit wrapper
- ✅ Production bundled web app
- ⚠️ JavaScript ↔ Native bridge is disabled for runtime stability
- ✅ Persistent browser `localStorage`
- ✅ Audio engine with procedural music
- ✅ Social sharing (jackpot cards)
- ✅ Node test coverage for game logic, save migration, and generated web smoke flows

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

3. **Verify bundled HTML resources**
   - `index.html` is the primary WebView entry point
   - `stoke.html` is kept in sync by `npm run build:web`
   - ✅ Copy items if needed
   - ✅ Add to targets: blocks

4. **Update Info.plist / privacy resources**
   - Copy settings from `Info-Template.plist`
   - Or merge manually (see SETUP.md)
   - Include `PrivacyInfo.xcprivacy` in the app target

5. **Build & Run**
   - Select target device
   - ⌘R to build and run

## 📂 Project Structure

```
blocks/
├── blocksApp.swift          # App entry point
├── ContentView.swift        # Main UI + WebView + message handler
├── PrivacyInfo.xcprivacy    # First-party privacy manifest
├── stoke_files/
│   ├── index.html           # Generated WebView entry point
│   ├── stoke.html           # Generated compatibility copy
│   ├── index.template.html  # HTML shell template
│   ├── stoke-app.jsx        # React game source
│   ├── stoke-core.mjs       # Testable puzzle rules
│   └── stoke-save.mjs       # Testable save/streak migration
├── stoke_files/AdMobManager.swift       # Deprecated placeholder
├── stoke_files/PurchaseManager.swift    # RevenueCat integration
├── WebView.swift           # (deprecated - merged into ContentView)
├── Info-Template.plist     # Info.plist configuration template
├── SETUP.md               # Detailed setup instructions
└── README.md              # This file
```

## 🔧 Configuration

### AdMob Setup

Ad unit IDs are present in the web app and Info template, but native presentation is disabled until the safe bridge is re-enabled:
```
App ID: ca-app-pub-7262617456411456~5433417356
Banner: ca-app-pub-7262617456411456/9508273591
Interstitial: ca-app-pub-7262617456411456/6307395181
Rewarded: ca-app-pub-7262617456411456/7812048544
```

Before release, verify these IDs in AdMob, add UMP consent, test on a real device, and make sure App Privacy labels match the final ad behavior.

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
4. Re-enable and test `NativeBridgeMode.storageAndMonetization` only after the WebKit message-handler crash is resolved.

## 🎯 Native Bridge Status

`ContentView.swift` still contains storage and monetization bridge code, but the live app currently runs with `bridgeMode: .disabled`. The JavaScript app falls back to local browser storage and browser/test monetization behavior.

See `BRIDGE-API.md` for the inactive bridge contract.

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

### Web Build and Tests
```bash
npm run build:web --cache /tmp/stoke-npm-cache
npm test --cache /tmp/stoke-npm-cache
```

### Debug WebView
1. Run app on device
2. Open Safari → Develop → [Your Device] → [App Name]
3. Access full JavaScript console

## 📋 Pre-Production Checklist

- [ ] Replace RevenueCat test key with production key
- [ ] Re-enable safe native bridge mode without WebKit message-handler crashes
- [ ] Add/verify UMP consent before requesting ads
- [ ] Add privacy policy URL to App Store listing
- [ ] Review App Privacy labels against AdMob, UMP, RevenueCat, and local storage
- [ ] Configure App Tracking Transparency messaging
- [ ] Test all ad placements on real device
- [ ] Test all purchase flows in sandbox
- [ ] Archive Release build for TestFlight
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
