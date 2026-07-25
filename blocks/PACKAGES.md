# Swift Package Dependencies for STOKE

This project uses external dependencies for ads and in-app purchases. You can add them via Xcode's built-in Swift Package Manager.

## Adding Packages in Xcode

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. Add each package below:

### Google Mobile Ads SDK (AdMob)

```
Repository URL: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
Version: 11.0.0 (or latest)
```

**What to add to your target:**
- `GoogleMobileAds`
- `GoogleMobileAdsFramework` (if needed)

### RevenueCat SDK

```
Repository URL: https://github.com/RevenueCat/purchases-ios.git
Version: 4.0.0 (or latest)
```

**What to add to your target:**
- `RevenueCat`

## Verifying Installation

After adding the packages:

1. Build the project (⌘B)
2. Check that imports work:
   ```swift
   import GoogleMobileAds
   import RevenueCat
   ```
3. If you see build errors, try:
   - File → Packages → Reset Package Caches
   - File → Packages → Update to Latest Package Versions
   - Clean build folder (⌘⇧K)

## Alternative: CocoaPods

If you prefer CocoaPods, use the included `Podfile`:

```bash
# Install CocoaPods if needed
sudo gem install cocoapods

# Install dependencies
pod install

# Open workspace (not project!)
open blocks.xcworkspace
```

## Troubleshooting

### "No such module 'GoogleMobileAds'"
- Ensure the package is added to your app target (not just the project)
- Try cleaning and rebuilding
- Check that the package appears in Project Navigator under "Package Dependencies"

### "No such module 'RevenueCat'"
- Same as above
- Verify you're importing `RevenueCat` not `Purchases`

### Build takes a long time
- First build downloads and compiles packages (can take 5-10 minutes)
- Subsequent builds are much faster

### Packages won't download
- Check your internet connection
- File → Packages → Reset Package Caches
- Restart Xcode

## Package Versions

Current recommended versions:
- **GoogleMobileAds**: 11.0.0+
- **RevenueCat**: 4.0.0+

These are tested and working. You can try newer versions, but test thoroughly.
