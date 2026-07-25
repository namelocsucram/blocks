# STOKE - Quick Reference Card

## 🚀 Getting Started (5 Minutes)

1. **Add dependencies** (choose one):
   - SPM: File → Add Packages → Add Google-Mobile-Ads & RevenueCat
   - CocoaPods: `pod install` then open `.xcworkspace`

2. **Add stoke.html**: Drag into Xcode, check "Copy items"

3. **Update Info.plist**: Copy keys from `Info-Template.plist`

4. **Build & Run**: ⌘R

## 📁 Key Files

| File | What It Does |
|------|--------------|
| `blocksApp.swift` | App entry, init AdMob & RevenueCat |
| `ContentView.swift` | Main view + WebView + bridge |
| `AdMobManager.swift` | Show ads (banner/interstitial/rewarded) |
| `PurchaseManager.swift` | Handle IAP (coin packs) |
| `stoke.html` | The game itself |

## 🔧 Common Tasks

### Enable Test Ads
In `AdMobManager.swift`:
```swift
GADMobileAds.sharedInstance().requestConfiguration
    .testDeviceIdentifiers = ["YOUR_DEVICE_ID"]
```

### Change API Key (Production)
In `PurchaseManager.swift`:
```swift
private let apiKey = "appl_YOUR_PRODUCTION_KEY"
```

### Debug JavaScript
Safari → Develop → [Device] → [App Name]

### Check If HTML Is Bundled
Build Phases → Copy Bundle Resources → should see `stoke.html`

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Blank screen | Check HTML is in bundle resources |
| "No such module" | Packages not added to app target |
| Ads not showing | Must use real device, not simulator |
| Purchase fails | Need sandbox account from App Store Connect |

## 📲 Testing Checklist

- [ ] App launches
- [ ] Game loads
- [ ] Score persists after restart
- [ ] Banner ad shows
- [ ] Can trigger interstitial (play 3 games)
- [ ] Rewarded ad works
- [ ] Coin shop opens
- [ ] Can make purchase (sandbox)

## 📦 Dependencies

```
Google-Mobile-Ads-SDK 11.0+
RevenueCat 4.0+
```

**Add via:** File → Add Package Dependencies
- https://github.com/googleads/swift-package-manager-google-mobile-ads.git
- https://github.com/RevenueCat/purchases-ios.git

## 🔑 Ad Unit IDs (Pre-Configured)

```
App: ca-app-pub-7262617456411456~5433417356
Banner: .../9508273591
Interstitial: .../6307395181
Rewarded: .../7812048544
```

## 💰 IAP Products (To Create)

Create in App Store Connect → In-App Purchases:
- `coins_100` - $0.99
- `coins_350` - $2.99
- `coins_800` - $4.99
- `coins_2000` - $9.99

## 🌉 JavaScript Bridge API

```javascript
// Storage
await window.storage.set(key, value)
await window.storage.get(key)

// Ads
await window.Capacitor.Plugins.AdMob.showBanner({...})
await window.Capacitor.Plugins.AdMob.showRewardVideoAd()

// Purchases
const {offerings} = await window.Capacitor.Plugins.Purchases.getOfferings()
await window.Capacitor.Plugins.Purchases.purchasePackage({aPackage})

// Platform check
window.Capacitor.isNativePlatform() // true in app, false in browser
```

## 📋 Info.plist Required Keys

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-7262617456411456~5433417356</string>

<key>NSUserTrackingUsageDescription</key>
<string>This helps us show you more relevant ads</string>

<key>SKAdNetworkItems</key>
<array><!-- See Info-Template.plist for full list --></array>
```

## 🎯 Pre-Production Checklist

- [ ] RevenueCat test key → production key
- [ ] Test device IDs removed
- [ ] All ad placements tested
- [ ] All IAP flows tested
- [ ] Privacy policy added
- [ ] ATT configured

## 📚 Documentation

- **README.md** - Overview & quick start
- **SETUP.md** - Detailed setup
- **BRIDGE-API.md** - JavaScript API docs
- **ARCHITECTURE.md** - How it all works
- **CHECKLIST.md** - Full testing checklist

## 🆘 Getting Help

1. Check console logs (Xcode Console + Safari Web Inspector)
2. Review SETUP.md for detailed config
3. Check ARCHITECTURE.md to understand flow
4. Use Safari debugger for JavaScript issues

## ⌨️ Xcode Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘B | Build |
| ⌘R | Run |
| ⌘. | Stop |
| ⌘⇧K | Clean build |
| ⌘0 | Show/hide navigator |
| ⌘⌥C | Show console |

## 🔍 Debugging

### Swift Errors
Check Xcode console (⌘⌥C)

### JavaScript Errors
Safari → Develop → [Device] → [App]

### Ad Issues
Check AdMob dashboard + Xcode console

### Purchase Issues
Check RevenueCat dashboard + verify sandbox account

## 📈 Analytics (Optional)

To add Firebase Analytics:
```swift
// Add Firebase to Package Dependencies
// In blocksApp.swift init():
FirebaseApp.configure()
```

## 🎨 Customization

### Change Game Background
In `ContentView.swift`:
```swift
Color(red: 0.07, green: 0.03, blue: 0.12) // Current purple
```

### Adjust Ad Frequency
In `stoke.html`:
```javascript
const INTERSTITIAL_EVERY = 3; // Change to 5, 10, etc.
```

### Modify Coin Prices
Edit `COIN_PACKAGES` in `stoke.html` and update in App Store Connect

## 🎮 Game Features

- **Daily Objectives** - 3 goals per day, coin rewards
- **Streak System** - Track consecutive days, freeze available every 7 days
- **Heat Multiplier** - Up to 4× score boost
- **Jackpot** - Clear board at max heat
- **Boosters** - Reroll (20 coins), Eraser (15 coins)
- **Social Sharing** - Share jackpot achievements

## 🏗️ Build Configurations

### Debug (Development)
- Test ads
- Sandbox purchases
- Console logging
- Source maps

### Release (Production)
- Real ads
- Production IAP
- Minimal logging
- Optimized bundle

Switch in Xcode: Product → Scheme → Edit Scheme → Run → Build Configuration

---

**Version:** 1.0.0
**Platform:** iOS 15.0+
**Language:** Swift 5.9+

For full documentation, see README.md and SETUP.md
