# STOKE - Xcode Project Checklist

Use this checklist to ensure everything is set up correctly.

## Current Implementation Status

- Native bridge: disabled again after simulator instability with `NativeBridgeMode.storageOnly`.
- Storage: uses WebView `localStorage` while the native bridge is disabled.
- RevenueCat bridge: still inactive; monetization handlers remain disabled until `NativeBridgeMode.storageAndMonetization` is ready and `PurchaseManager` has a production `appl_...` key.
- AdMob bridge: still inactive until Google Mobile Ads is wired through the safer bridge mode.
- Web app bundling: production-style HTML generated from `stoke_files/stoke-app.jsx` with local React/esbuild output; no CDN React or runtime Babel in shipped HTML.
- Core game tests: `node:test` coverage now exercises placement validation, blocked-board detection, line clearing, piece fallback, heat/combo scoring, and gold-piece scoring via `stoke_files/stoke-core.mjs`.
- Save migration tests: `node:test` coverage now exercises old `muted` save migration, streak rollover/reset, streak-freeze use, and daily-goal refresh via `stoke_files/stoke-save.mjs`.
- Web smoke tests: `node:test` plus `happy-dom` now renders the generated app bundle and checks launch, board/tray render, daily objectives, coin shop, drag placement, game over, and rewarded-rescue flow.
- Privacy manifest: first-party `PrivacyInfo.xcprivacy` is present and declares no first-party collection/tracking while the bridge remains disabled and gameplay data stays local.
- Production blockers: App Privacy labels, privacy policy URL, AdMob/UMP behavior, RevenueCat production key, App Store Connect products, and real-device sandbox tests still need final verification before TestFlight.

## ✅ Initial Setup

- [ ] **Project opened in Xcode**
  - Open `blocks.xcodeproj` (or `blocks.xcworkspace` if using CocoaPods)

- [ ] **Dependencies added**
  - [ ] Google Mobile Ads SDK installed
  - [ ] RevenueCat SDK installed
  - [ ] Build succeeds (⌘B)

- [ ] **HTML file added**
  - [ ] `stoke.html` is in project navigator
  - [ ] File is added to target (check Target Membership in File Inspector)
  - [ ] Shows in Build Phases → Copy Bundle Resources

- [ ] **Info.plist configured**
  - [ ] `GADApplicationIdentifier` key added with AdMob app ID
  - [ ] `SKAdNetworkItems` array added
  - [ ] `NSUserTrackingUsageDescription` added
  - [ ] `UIViewControllerBasedStatusBarAppearance` set to `NO`
  - [ ] Privacy policy URL finalized for App Store metadata

## ✅ Code Integration

- [ ] **All Swift files present:**
  - [ ] `blocksApp.swift` - App entry point
  - [ ] `ContentView.swift` - Main view with WebView
  - [ ] `AdMobManager.swift` - AdMob integration
  - [ ] `PurchaseManager.swift` - RevenueCat integration
  - [ ] `WebView.swift` - (optional, deprecated)

- [ ] **No build errors**
  - [ ] Imports work (GoogleMobileAds, RevenueCat)
  - [ ] No red errors in Xcode
  - [ ] Clean build succeeds (⌘⇧K then ⌘B)

## ✅ Testing - Basic Functionality

- [ ] **App launches**
  - [ ] Game loads and displays
  - [ ] Can drag and place pieces
  - [ ] Lines clear correctly
  - [ ] Heat system works

- [ ] **Storage works**
  - [ ] Score persists after app restart
  - [ ] Best score saves
  - [ ] Settings (sound toggles) persist
  - [ ] Daily streak increments

## ✅ Testing - AdMob Integration

- [ ] **Banner ad**
  - [ ] Shows at bottom of screen
  - [ ] Doesn't overlap game content
  - [ ] Displays test ad (or real if configured)

- [ ] **Interstitial ad**
  - [ ] Shows after 3 completed games
  - [ ] Can be dismissed
  - [ ] Game continues after dismissal

- [ ] **Rewarded ad**
  - [ ] Triggers when game is over
  - [ ] "Watch ad to continue" button works
  - [ ] Clears 6 random blocks after watching
  - [ ] Game continues after reward

## ✅ Testing - RevenueCat Integration

- [ ] **Coin shop opens**
  - [ ] "🪙 Get coins" button works
  - [ ] Shows 4 coin tiers
  - [ ] Prices load (live or static)

- [ ] **Purchase flow**
  - [ ] Tapping a tier initiates purchase
  - [ ] StoreKit sheet appears
  - [ ] Purchase completes (sandbox)
  - [ ] Coins are added to balance

## ✅ Testing - Game Features

- [ ] **Daily objectives**
  - [ ] Toggle panel works
  - [ ] Progress bars update during gameplay
  - [ ] Can claim rewards when complete
  - [ ] Coins added correctly

- [ ] **Boosters**
  - [ ] Reroll costs 20 coins and refreshes tray
  - [ ] Eraser costs 15 coins and removes one block
  - [ ] Tooltips show when insufficient coins

- [ ] **Jackpot system**
  - [ ] Heat reaches max (100%)
  - [ ] Bomb piece appears in tray
  - [ ] Placing bomb clears entire board
  - [ ] Share button appears after jackpot

## ✅ Device Testing

- [ ] **iPhone (different sizes)**
  - [ ] iPhone SE (small screen)
  - [ ] iPhone 15 Pro (standard)
  - [ ] iPhone 15 Pro Max (large)

- [ ] **iPad** (optional)
  - [ ] Layout looks good
  - [ ] Touch controls work
  - [ ] Ads display properly

- [ ] **Different iOS versions**
  - [ ] iOS 15 (minimum)
  - [ ] Latest iOS version

## ✅ Production Preparation

- [ ] **AdMob**
  - [ ] Test device IDs removed
  - [ ] Real ad unit IDs verified in AdMob console
  - [ ] Ads showing real content (not test ads)

- [ ] **RevenueCat**
  - [ ] Test API key replaced with production key
  - [ ] Products created in App Store Connect
  - [ ] Products configured in RevenueCat dashboard
  - [ ] Sandbox testing completed successfully

- [ ] **App Store Assets**
  - [ ] App icon created (all sizes)
  - [ ] Screenshots captured
  - [ ] Privacy policy written and hosted
  - [ ] App description written

- [ ] **Compliance**
  - [ ] App Tracking Transparency implemented
  - [x] First-party privacy manifest included
  - [ ] App Privacy labels reviewed against AdMob, UMP, RevenueCat, and first-party local storage behavior
  - [ ] Age rating appropriate
  - [ ] Content complies with App Store guidelines

## ✅ Final Build

- [ ] **Build configuration**
  - [ ] Scheme set to Release
  - [ ] Signing configured
  - [ ] Version and build number set
  - [ ] Archive builds successfully

- [ ] **TestFlight**
  - [ ] Uploaded to App Store Connect
  - [ ] Internal testing completed
  - [ ] External testing (optional)

- [ ] **App Review Submission**
  - [ ] All metadata complete
  - [ ] Demo account provided (if needed)
  - [ ] Review notes added
  - [ ] Submitted for review

## 📝 Notes

Record any issues or special configurations here:

```
[Your notes here]
```

## 🎉 Status

Current status: **[ ] Ready for Development** / **[ ] Ready for Testing** / **[ ] Ready for Production**

Last updated: [Date]
Tested by: [Name]
