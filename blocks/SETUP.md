# STOKE Game - Xcode Setup Instructions

## Overview
This native iOS app wraps the bundled STOKE web game in WebKit. Native AdMob and RevenueCat code is present, but the live bridge is currently disabled for runtime stability.

## Current State

- Primary entry point: generated `stoke_files/index.html`.
- Source entry point: `stoke_files/stoke-app.jsx`.
- Build command: `npm run build:web --cache /tmp/stoke-npm-cache`.
- Test command: `npm test --cache /tmp/stoke-npm-cache`.
- Runtime bridge: `bridgeMode: .disabled` in `ContentView.swift`.
- Storage: WebView `localStorage` while the bridge is disabled.
- Native ads/purchases: blocked until `NativeBridgeMode.storageAndMonetization` is safely re-enabled and tested.

## Setup Steps

### 1. Add Dependencies

#### Using Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies**
2. Add the following packages:

**Google Mobile Ads SDK:**
```
https://github.com/googleads/swift-package-manager-google-mobile-ads.git
```
Version: 11.0.0 or later

**RevenueCat SDK:**
```
https://github.com/RevenueCat/purchases-ios.git
```
Version: 4.0.0 or later

#### Or using CocoaPods

Create a `Podfile` in your project root:

```ruby
platform :ios, '15.0'
use_frameworks!

target 'blocks' do
  pod 'Google-Mobile-Ads-SDK', '~> 11.0'
  pod 'RevenueCat', '~> 4.0'
end
```

Then run: `pod install`

### 2. Update Info.plist

Add the following keys to your `Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-7262617456411456~5433417356</string>

<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
  <!-- Add more SKAdNetwork IDs as needed -->
</array>

<key>NSUserTrackingUsageDescription</key>
<string>Allow tracking to help show ads that are more relevant to you and support STOKE.</string>

<key>UIViewControllerBasedStatusBarAppearance</key>
<false/>
```

### 3. Verify Web Bundle Resources

1. Run `npm run build:web --cache /tmp/stoke-npm-cache`
2. Verify `stoke_files/index.html` and `stoke_files/stoke.html` are included in the app target
3. Verify `PrivacyInfo.xcprivacy` is included in the app target

### 4. Configure App Transport Security (for development)

If testing with local resources, add to Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Remove this for production!**

### 5. Set Up AdMob

1. Create an AdMob account at https://admob.google.com
2. The app ID and ad unit IDs are already configured:
   - App ID: `ca-app-pub-7262617456411456~5433417356`
   - Banner: `ca-app-pub-7262617456411456/9508273591`
   - Interstitial: `ca-app-pub-7262617456411456/6307395181`
   - Rewarded: `ca-app-pub-7262617456411456/7812048544`

### 6. Set Up RevenueCat

1. Create a RevenueCat account at https://www.revenuecat.com
2. Create a new app in RevenueCat dashboard
3. Get your API key (replace the test key in `PurchaseManager.swift`)
4. Set up products in App Store Connect:
   - `coins_100` - 100 coins
   - `coins_350` - 350 coins
   - `coins_800` - 800 coins
   - `coins_2000` - 2000 coins
5. Configure these products in RevenueCat

### 7. Build & Run

1. Select your target device (iOS 15.0+)
2. Build and run (⌘R)

## Project Structure

```
blocks/
├── blocksApp.swift          # App entry point
├── ContentView.swift        # Main view with WebView
├── WebView.swift           # WebKit wrapper (deprecated - merged into ContentView)
├── AdMobManager.swift      # AdMob integration
├── PurchaseManager.swift   # RevenueCat integration
└── stoke.html             # Game HTML file
```

## Features

⚠️ Native AdMob bridge staged, currently disabled
⚠️ Native RevenueCat bridge staged, currently disabled
✅ Browser/test banner, interstitial, rewarded-rescue, and coin-pack flows
✅ Persistent storage via WebView localStorage
✅ Daily objectives system
✅ Streak tracking

## Testing

### Test Ads (Development)
Use test device IDs in `AdMobManager.swift`:

```swift
GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["YOUR_TEST_DEVICE_ID"]
```

### Test Purchases (Sandbox)
1. Create a sandbox tester in App Store Connect
2. Sign in with sandbox account on device
3. RevenueCat will automatically detect sandbox mode

## Production Checklist

- [ ] Replace RevenueCat test key with production key
- [ ] Remove NSAllowsArbitraryLoads from Info.plist
- [ ] Re-enable safe native bridge mode without WebKit message-handler crashes
- [ ] Add/verify UMP consent before ad requests
- [ ] Test all ad placements on real device
- [ ] Test all IAP flows in sandbox
- [ ] Add privacy policy URL
- [ ] Review App Privacy labels against final AdMob, UMP, RevenueCat, and first-party storage behavior
- [ ] Configure App Tracking Transparency
- [ ] Submit for App Review

## Troubleshooting

**Ads not showing:**
- Check Info.plist has GADApplicationIdentifier
- Verify ad unit IDs match AdMob dashboard
- Check console for AdMob errors
- Make sure test device is configured

**Purchases not working:**
- Verify products exist in App Store Connect
- Check RevenueCat API key
- Ensure sandbox tester is signed in
- Check console for RevenueCat errors

**WebView blank:**
- Verify stoke.html is in app bundle
- Check Safari console for JS errors
- Test in Safari first

## Support

For issues, check:
- AdMob documentation: https://developers.google.com/admob/ios
- RevenueCat docs: https://docs.revenuecat.com
- WebKit debugging: Safari → Develop → [Device] → [App]
