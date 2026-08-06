# JavaScript ↔ Native Bridge API Reference

This document describes the JavaScript/native bridge contract. Storage and AdMob are implemented but flag-gated; RevenueCat purchase APIs remain inactive by default.

## Overview

The bridge works by injecting JavaScript objects (`window.Capacitor`, `window.storage`) that send messages to Swift code via WebKit's message handlers. Responses come back via JavaScript callbacks.

Current runtime status: `ContentView.swift` defaults to `bridgeMode: .disabled`, so the shipped app uses WebView `localStorage` and no native ad bridge. Passing `-STOKEStorageBridgeEnabled` or setting `STOKE_STORAGE_BRIDGE_ENABLED=1` enables experimental `window.storage` backed by native `UserDefaults`. Passing `-STOKEAdMobBridgeEnabled` or setting `STOKE_ADMOB_BRIDGE_ENABLED=1` enables storage plus `window.Capacitor.Plugins.AdMob`. Purchases remain inactive unless `-STOKEPurchasesBridgeEnabled` or `STOKE_PURCHASES_BRIDGE_ENABLED=1` is explicitly enabled.

## Storage API

### `window.storage.get(key)`

Retrieves a value from persistent storage (UserDefaults).

**Parameters:**
- `key` (string) - The storage key

**Returns:** Promise<{value?: string}>

**Example:**
```javascript
const result = await window.storage.get("stoke-save");
if (result && result.value) {
  const data = JSON.parse(result.value);
  console.log("Loaded:", data);
}
```

### `window.storage.set(key, value)`

Saves a value to persistent storage.

**Parameters:**
- `key` (string) - The storage key
- `value` (string) - The value to store (serialize objects as JSON)

**Returns:** Promise<void>

**Example:**
```javascript
const data = { score: 1000, best: 5000 };
await window.storage.set("stoke-save", JSON.stringify(data));
```

## AdMob API

All AdMob methods are accessed via `window.Capacitor.Plugins.AdMob`.

### `initialize()`

Initializes the AdMob SDK. Called automatically on app launch.

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.initialize();
```

### `showBanner(options)`

Shows a banner ad at the specified position.

**Parameters:**
- `options` (object)
  - `adId` (string) - Ad unit ID
  - `adSize` (string) - "BANNER" | "LARGE_BANNER" | "MEDIUM_RECTANGLE"
  - `position` (string) - "TOP_CENTER" | "BOTTOM_CENTER"

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.showBanner({
  adId: "ca-app-pub-XXXXXX/XXXXXX",
  adSize: "BANNER",
  position: "BOTTOM_CENTER"
});
```

### `removeBanner()`

Removes the currently displayed banner ad.

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.removeBanner();
```

### `prepareInterstitial(options)`

Preloads an interstitial ad for later display.

**Parameters:**
- `options` (object)
  - `adId` (string) - Ad unit ID

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.prepareInterstitial({
  adId: "ca-app-pub-XXXXXX/XXXXXX"
});
```

### `showInterstitial()`

Shows the preloaded interstitial ad.

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.showInterstitial();
```

### `prepareRewardVideoAd(options)`

Preloads a rewarded video ad.

**Parameters:**
- `options` (object)
  - `adId` (string) - Ad unit ID

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.AdMob.prepareRewardVideoAd({
  adId: "ca-app-pub-XXXXXX/XXXXXX"
});
```

### `showRewardVideoAd()`

Shows the rewarded video ad and waits for completion.

**Returns:** Promise<void> - Resolves when user earns reward, rejects if cancelled/failed

**Example:**
```javascript
try {
  await window.Capacitor.Plugins.AdMob.showRewardVideoAd();
  console.log("User earned reward!");
} catch (error) {
  console.log("Ad failed or cancelled");
}
```

### `addListener(eventName, callback)`

Listens for ad events (alternative to promise-based API).

**Parameters:**
- `eventName` (string) - Event to listen for
  - `"onRewardedVideoAdReward"` - User completed rewarded video
- `callback` (function) - Called when event fires

**Example:**
```javascript
window.Capacitor.Plugins.AdMob.addListener(
  "onRewardedVideoAdReward",
  () => {
    console.log("Reward earned!");
    grantPlayerReward();
  }
);
```

## RevenueCat API

All purchase methods are accessed via `window.Capacitor.Plugins.Purchases`.

### `configure(options)`

Configures the RevenueCat SDK. In the current architecture, the production API key must stay owned by Swift in `PurchaseManager.swift`; JavaScript must not provide or override it.

**Parameters:**
- `options` (object)
  - No runtime API key parameter is accepted in production. Swift owns SDK configuration.

**Returns:** Promise<void>

**Example:**
```javascript
await window.Capacitor.Plugins.Purchases.configure();
```

### `getOfferings()`

Fetches available in-app purchase offerings.

**Returns:** Promise<{offerings: Object}>

**Example:**
```javascript
const { offerings } = await window.Capacitor.Plugins.Purchases.getOfferings();
const packages = offerings.current?.availablePackages || [];

packages.forEach(pkg => {
  console.log(pkg.identifier, pkg.product.priceString);
});
```

### `purchasePackage(options)`

Initiates a purchase flow for a specific package.

**Parameters:**
- `options` (object)
  - `aPackage` (object) - Package object from getOfferings()

**Returns:** Promise<void> - Resolves on success, rejects on failure/cancellation

**Example:**
```javascript
const { offerings } = await window.Capacitor.Plugins.Purchases.getOfferings();
const coinPack = offerings.current.availablePackages.find(
  p => p.identifier === "coins_100"
);

try {
  await window.Capacitor.Plugins.Purchases.purchasePackage({
    aPackage: coinPack
  });
  console.log("Purchase successful!");
  addCoins(100);
} catch (error) {
  console.log("Purchase failed:", error);
}
```

## Platform Detection

### `window.Capacitor.isNativePlatform()`

Returns true if running in the native app (vs browser).

**Returns:** boolean

**Example:**
```javascript
if (window.Capacitor.isNativePlatform()) {
  // Use native features
  await window.Capacitor.Plugins.AdMob.showBanner({...});
} else {
  // Show placeholder or alternative
  console.log("Running in browser, ads disabled");
}
```

## Error Handling

All bridge methods return promises. Always use try/catch:

```javascript
try {
  await window.Capacitor.Plugins.AdMob.showRewardVideoAd();
  // Success
} catch (error) {
  // Handle error
  console.error("Ad failed:", error);
  alert("Ad unavailable, try again later");
}
```

## Full Example: Rewarded Video Flow

```javascript
async function continueAfterGameOver() {
  // Check if running in native app
  if (!window.Capacitor.isNativePlatform()) {
    alert("Ads only available in the app");
    return;
  }
  
  try {
    // Show rewarded video
    await window.Capacitor.Plugins.AdMob.showRewardVideoAd();
    
    // User completed the ad, grant reward
    clearRandomBlocks(6);
    resumeGame();
    
  } catch (error) {
    // Ad failed to load or user closed it
    console.error("Rewarded ad error:", error);
    alert("Ad unavailable. Please try again.");
  }
}
```

## Full Example: In-App Purchase Flow

```javascript
async function buyCoins(tier) {
  try {
    // Fetch latest offerings
    const { offerings } = await window.Capacitor.Plugins.Purchases.getOfferings();
    
    // Find the package
    const pkg = offerings.current?.availablePackages.find(
      p => p.identifier === tier.id
    );
    
    if (!pkg) {
      alert("This coin pack is unavailable");
      return;
    }
    
    // Show loading state
    setLoading(true);
    
    // Initiate purchase
    await window.Capacitor.Plugins.Purchases.purchasePackage({
      aPackage: pkg
    });
    
    // Success! Grant coins
    addCoins(tier.coins);
    showToast(`You got ${tier.coins} coins!`);
    
  } catch (error) {
    // Purchase failed or cancelled
    if (error.message.includes("cancel")) {
      console.log("User cancelled purchase");
    } else {
      console.error("Purchase error:", error);
      alert("Purchase failed. Please try again.");
    }
  } finally {
    setLoading(false);
  }
}
```

## Debugging

### Safari Web Inspector

1. Run app on a real device
2. Open Safari on Mac
3. Safari → Develop → [Your Device] → [App Name]
4. Use console to test bridge commands:

```javascript
// Test storage
await window.storage.set("test", "hello");
const result = await window.storage.get("test");
console.log(result); // {value: "hello"}

// In storage-only mode, monetization bridge APIs are intentionally absent.
console.log(window.Capacitor); // undefined until storageAndMonetization is enabled
```

### Console Logs

Swift code logs to Xcode console, JavaScript logs to Safari console. Check both when debugging.

## Notes

- All async operations use Promises (use `async`/`await`)
- Storage values are always strings (serialize objects with `JSON.stringify`)
- Ad methods may fail silently if ads aren't loaded
- Purchase flows require App Store sandbox account for testing
- Bridge is only available when `window.Capacitor.isNativePlatform()` returns true
