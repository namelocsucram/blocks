# STOKE Game - Xcode Conversion Summary

This is a historical conversion summary. The current app is a native SwiftUI/WebKit wrapper around a production-bundled web game.

Current correction:
- The live app loads generated `stoke_files/index.html`.
- The native JavaScript bridge is currently disabled for runtime stability.
- Gameplay persistence currently uses WebView `localStorage`.
- Native AdMob and RevenueCat handlers are staged but inactive until a safe bridge mode is re-enabled and tested.
- TestFlight still requires privacy-label review, UMP/ATT verification, RevenueCat production key, App Store Connect products, and real-device sandbox testing.

## 📦 What Was Created

### Swift Files (Native Code)
1. **blocksApp.swift** - App entry point, initializes AdMob and RevenueCat
2. **ContentView.swift** - Main view containing WebView and message handler
3. **AdMobManager.swift** - AdMob integration (banner, interstitial, rewarded)
4. **PurchaseManager.swift** - RevenueCat integration (IAP)
5. **WebView.swift** - Deprecated (code merged into ContentView)

### Configuration Files
1. **Info-Template.plist** - All required Info.plist settings
2. **Podfile** - CocoaPods dependencies (alternative to SPM)

### Documentation
1. **README.md** - Project overview and quick start
2. **SETUP.md** - Detailed setup instructions
3. **PACKAGES.md** - Swift Package Manager guide
4. **BRIDGE-API.md** - JavaScript ↔ Native API reference
5. **CHECKLIST.md** - Testing and deployment checklist

### Game File
- **stoke.html** - Your original game (unchanged, ready to add to Xcode)

## 🚀 Next Steps

### 1. Add Dependencies (Choose One)

**Option A: Swift Package Manager** (Recommended)
```
File → Add Package Dependencies
- Google Mobile Ads: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
- RevenueCat: https://github.com/RevenueCat/purchases-ios.git
```

**Option B: CocoaPods**
```bash
pod install
open blocks.xcworkspace  # Important: use .xcworkspace!
```

### 2. Add HTML to Project
- Drag `stoke.html` into Xcode project navigator
- ✅ Check "Copy items if needed"
- ✅ Check "blocks" target

### 3. Update Info.plist
- Copy all keys from `Info-Template.plist` to your `Info.plist`
- Or merge manually (see SETUP.md for details)

### 4. Build & Test
```
⌘B - Build
⌘R - Run
```

## ✨ What Works Out of the Box

✅ **Game loads in native WebView**
- Full React/JavaScript functionality
- Drag-and-drop controls
- Audio/music
- Canvas rendering

✅ **Persistent Storage**
- Saves to WebView `localStorage` while the native bridge is disabled
- Score, settings, streaks all persist

⚠️ **AdMob Integration**
- Native AdMob code is staged but inactive while the bridge is disabled
- Browser/test placeholder flows cover banner, interstitial, and rewarded rescue

⚠️ **In-App Purchases**
- 4 coin packs are represented in the UI
- RevenueCat code is staged but inactive while the bridge is disabled

✅ **Daily Objectives**
- Track progress across app sessions
- Coin rewards

## 🔧 Configuration Needed

### AdMob
1. The ad unit IDs in the code are **already configured**:
   ```
   App: ca-app-pub-7262617456411456~5433417356
   Banner: .../9508273591
   Interstitial: .../6307395181
   Rewarded: .../7812048544
   ```

2. For testing, add your device as a test device in `AdMobManager.swift`

### RevenueCat
1. Create account at https://www.revenuecat.com
2. Get API key and replace in `PurchaseManager.swift`:
   ```swift
   private let apiKey = "appl_YOUR_KEY_HERE"
   ```
3. Create products in App Store Connect:
   - `coins_100`, `coins_350`, `coins_800`, `coins_2000`

## 📱 How It Works

### Architecture
```
┌─────────────────────┐
│   SwiftUI View      │ ← ContentView.swift
│   (ContentView)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   WKWebView         │ ← WebViewContainer
│   (loads index.html)│
└──────────┬──────────┘
           │
           ▼ JavaScript Bridge (currently disabled)
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌──────────┐
│ AdMob   │ │RevenueCat│
│ Manager │ │ Manager  │
└─────────┘ └──────────┘
```

### Communication Flow
1. **Current runtime**: JavaScript uses local browser storage and browser/test monetization fallbacks.
2. **Inactive bridge path**: JavaScript can call `window.storage` / `window.Capacitor` only after a safe bridge mode is re-enabled.

## 🧪 Testing Checklist

Quick test to verify everything works:

- [ ] App launches and shows game
- [ ] Can place pieces and clear lines
- [ ] Score persists after restart
- [ ] Browser/test banner placeholder appears
- [ ] Game over shows "Watch ad to continue"
- [ ] Coin shop opens when tapped
- [ ] Daily objectives panel toggles

See **CHECKLIST.md** for comprehensive testing.

## 📚 Documentation Quick Reference

| File | Purpose |
|------|---------|
| README.md | Project overview, quick start |
| SETUP.md | Detailed setup instructions |
| PACKAGES.md | Dependency installation guide |
| BRIDGE-API.md | JavaScript API documentation |
| CHECKLIST.md | Testing and deployment checklist |
| Info-Template.plist | Info.plist configuration template |

## 🆘 Common Issues

### "App builds but shows blank screen"
→ Check that `stoke.html` is in Build Phases → Copy Bundle Resources

### "No such module 'GoogleMobileAds'"
→ Make sure packages are added to **app target** not just project

### "Ads don't show"
→ Must test on real device (simulator doesn't show real ads)

### "Purchases fail"
→ Need sandbox tester account from App Store Connect

### "JavaScript errors"
→ Use Safari → Develop → [Device] → [App] to debug

## 🎯 Production Checklist

Before submitting to App Store:

- [ ] Replace RevenueCat test key with production key
- [ ] Remove test device IDs from AdMob config
- [ ] Test all flows on real device
- [ ] Add privacy policy URL
- [ ] Configure App Tracking Transparency
- [ ] Create App Store assets (icon, screenshots)

See **CHECKLIST.md** for complete list.

## 💰 Monetization Summary

### Ad Placements
1. **Banner** - Always visible at bottom ($0.20-0.50 CPM)
2. **Interstitial** - After every 3 games ($3-7 CPM)
3. **Rewarded** - Optional continue after game over ($10-20 CPM)

### In-App Purchases
- 100 coins - $0.99
- 350 coins - $2.99 (17% better value)
- 800 coins - $4.99 (19% better value)
- 2000 coins - $9.99 (25% better value)

### Coin Usage
- Reroll pieces: 20 coins
- Erase block: 15 coins
- Earned through gameplay (1 per line cleared)
- Earned through daily objectives

## 🎊 You're Ready!

The app currently has:
- ✅ WebKit-powered rendering
- ✅ Production-bundled web app
- ✅ Local persistent storage
- ⚠️ Native ad integration staged but disabled
- ⚠️ In-app purchases staged but disabled
- ⚠️ Production monetization still blocked on bridge, consent, account, and device testing

**Next:** Follow the setup steps in SETUP.md to configure dependencies and start testing!

---

Need help? Check the documentation files or review the code comments in each Swift file.

**Happy coding! 🚀**
