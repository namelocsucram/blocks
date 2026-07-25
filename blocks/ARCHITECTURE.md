# STOKE Project Architecture

## File Structure
```
blocks/
│
├── 📱 App Files
│   ├── blocksApp.swift              # App entry point
│   ├── ContentView.swift            # Main UI + WebView + Bridge
│   ├── AdMobManager.swift          # Ad integration
│   ├── PurchaseManager.swift       # IAP integration
│   └── WebView.swift               # (Deprecated)
│
├── 🎮 Game Files
│   └── stoke.html                  # React game (add to Xcode)
│
├── ⚙️ Configuration
│   ├── Info.plist                  # (Update with Info-Template.plist)
│   ├── Info-Template.plist         # Configuration template
│   └── Podfile                     # CocoaPods dependencies
│
└── 📖 Documentation
    ├── README.md                   # Project overview
    ├── SETUP.md                    # Setup instructions
    ├── PACKAGES.md                 # SPM/CocoaPods guide
    ├── BRIDGE-API.md              # JavaScript API docs
    ├── CHECKLIST.md               # Testing checklist
    ├── CONVERSION-SUMMARY.md      # This conversion summary
    └── ARCHITECTURE.md            # This file
```

## Component Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         iOS App Shell                         │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              SwiftUI Layer                             │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │           blocksApp.swift                        │  │  │
│  │  │  • App lifecycle                                 │  │  │
│  │  │  • Initialize AdMob                             │  │  │
│  │  │  • Initialize RevenueCat                        │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                          │                              │  │
│  │                          ▼                              │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │           ContentView.swift                      │  │  │
│  │  │  • Main view structure                           │  │  │
│  │  │  • WebViewContainer (WKWebView wrapper)         │  │  │
│  │  │  • WebViewMessageHandler (bridge)               │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              WebKit Layer                              │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │           WKWebView                              │  │  │
│  │  │  • Loads stoke.html                             │  │  │
│  │  │  • Executes JavaScript                          │  │  │
│  │  │  • Renders React components                     │  │  │
│  │  │  • Handles touch events                         │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                          │                                    │
│                          │ Message Passing                    │
│                          ▼                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              Bridge Layer                              │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │     WKScriptMessageHandler                       │  │  │
│  │  │  • Receives: storage, admobAction, purchaseAction│  │  │
│  │  │  • Routes to appropriate manager                 │  │  │
│  │  │  • Sends responses back to JavaScript           │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                          │                                    │
│         ┌────────────────┼────────────────┐                  │
│         │                │                │                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  UserDefaults│  │AdMobManager │  │PurchaseMgr  │          │
│  │             │  │             │  │             │          │
│  │ • Save data │  │ • Banner    │  │ • Get offers│          │
│  │ • Load data │  │ • Interstit.│  │ • Purchase  │          │
│  │             │  │ • Rewarded  │  │ • Restore   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                          │                │                  │
│                          ▼                ▼                  │
│                   ┌─────────────┐  ┌─────────────┐          │
│                   │   AdMob SDK │  │RevenueCat SDK│         │
│                   └─────────────┘  └─────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Storage Flow
```
JavaScript                     Bridge                    Swift
────────────────────────────────────────────────────────────────
storage.set(key, value) ────► Message Handler ────► UserDefaults
                                    │
storage.get(key) ────────────► Fetch value ────► Return to JS ◄┘
                                    │
                              Callback: storageCallbacks[key](result)
```

### Ad Display Flow
```
JavaScript                     Bridge                    Native
────────────────────────────────────────────────────────────────
AdMob.showBanner() ─────────► Post notification ─────► AdMobManager
                                                            │
                                                            ▼
                                                    GADBannerView.show()
                                                            │
                                                            ▼
                                                    Ad displays on screen
```

### Purchase Flow
```
JavaScript                     Bridge                    Native
────────────────────────────────────────────────────────────────
Purchases.getOfferings() ───► Post notification ─────► PurchaseManager
                                                            │
                                                            ▼
                                                    RevenueCat.getOfferings()
                                                            │
                                                            ▼
                              Return offerings ◄───────── Callback
                                    │
Callback: offeringsCallback(data) ◄┘

purchasePackage(pkg) ────────► Post notification ─────► PurchaseManager
                                                            │
                                                            ▼
                                                    RevenueCat.purchase()
                                                            │
                                                            ▼
                              Success/Error ◄──────── StoreKit transaction
                                    │
Callback: purchaseCallbacks.resolve/reject() ◄────────────┘
```

## Message Handler Events

### Received from JavaScript
| Message Name | Handled By | Purpose |
|--------------|-----------|---------|
| `storage` | WebViewMessageHandler | Get/set UserDefaults |
| `admobAction` | AdMobManager | Show/hide ads |
| `purchaseAction` | PurchaseManager | Get offerings/purchase |

### Sent to JavaScript
| Notification | JavaScript Callback | Purpose |
|--------------|---------------------|---------|
| `rewardedAdEarned` | `admobListeners.onRewardedVideoAdReward()` | User completed rewarded ad |
| `rewardedAdFailed` | `rewardedAdCallbacks.reject()` | Ad failed to load |
| `offeringsLoaded` | `offeringsCallback()` | IAP products loaded |
| `purchaseSuccess` | `purchaseCallbacks.resolve()` | Purchase completed |
| `purchaseFailed` | `purchaseCallbacks.reject()` | Purchase failed |
| `purchaseCancelled` | `purchaseCallbacks.reject()` | User cancelled |

## Class Responsibilities

### ContentView
- **Purpose**: Main SwiftUI view
- **Responsibilities**:
  - Display WebView
  - Initialize message handler
  - Configure ad and purchase managers
- **Dependencies**: WebViewMessageHandler, AdMobManager, PurchaseManager

### WebViewMessageHandler
- **Purpose**: JavaScript ↔ Swift bridge
- **Responsibilities**:
  - Receive messages from JavaScript
  - Route to appropriate manager
  - Send responses back to JavaScript
  - Listen for native notifications
- **Dependencies**: WKWebView, NotificationCenter, UserDefaults

### AdMobManager
- **Purpose**: Ad monetization
- **Responsibilities**:
  - Initialize AdMob SDK
  - Show/hide banner ads
  - Load and display interstitial ads
  - Load and display rewarded ads
  - Notify JavaScript of ad events
- **Dependencies**: GoogleMobileAds SDK

### PurchaseManager
- **Purpose**: In-app purchases
- **Responsibilities**:
  - Configure RevenueCat SDK
  - Fetch product offerings
  - Process purchases
  - Handle restoration
  - Notify JavaScript of purchase events
- **Dependencies**: RevenueCat SDK

## JavaScript API Surface

```javascript
// Platform detection
window.Capacitor.isNativePlatform() → boolean

// Storage
window.storage.get(key) → Promise<{value?: string}>
window.storage.set(key, value) → Promise<void>

// AdMob
window.Capacitor.Plugins.AdMob.initialize() → Promise<void>
window.Capacitor.Plugins.AdMob.showBanner(options) → Promise<void>
window.Capacitor.Plugins.AdMob.removeBanner() → Promise<void>
window.Capacitor.Plugins.AdMob.prepareInterstitial(options) → Promise<void>
window.Capacitor.Plugins.AdMob.showInterstitial() → Promise<void>
window.Capacitor.Plugins.AdMob.prepareRewardVideoAd(options) → Promise<void>
window.Capacitor.Plugins.AdMob.showRewardVideoAd() → Promise<void>
window.Capacitor.Plugins.AdMob.addListener(event, callback) → void

// RevenueCat
window.Capacitor.Plugins.Purchases.configure(options) → Promise<void>
window.Capacitor.Plugins.Purchases.getOfferings() → Promise<{offerings}>
window.Capacitor.Plugins.Purchases.purchasePackage(options) → Promise<void>
```

## Dependency Graph

```
blocksApp
    │
    └─► ContentView
            │
            ├─► WebViewMessageHandler
            │       │
            │       ├─► UserDefaults (storage)
            │       ├─► NotificationCenter (events)
            │       └─► WKWebView (JavaScript execution)
            │
            ├─► AdMobManager
            │       │
            │       ├─► GADMobileAds (SDK)
            │       ├─► GADBannerView
            │       ├─► GADInterstitialAd
            │       └─► GADRewardedAd
            │
            └─► PurchaseManager
                    │
                    └─► RevenueCat (SDK)
                            │
                            └─► StoreKit (Apple)
```

## External Dependencies

### Swift Packages (via SPM or CocoaPods)
1. **Google-Mobile-Ads-SDK** (11.0.0+)
   - AdMob monetization
   - Banner, interstitial, rewarded ads

2. **RevenueCat** (4.0.0+)
   - In-app purchase management
   - Receipt validation
   - Subscription handling

### Apple Frameworks
- **SwiftUI** - UI framework
- **WebKit** - Web content rendering
- **Foundation** - UserDefaults, networking
- **UIKit** - UIViewController integration

### JavaScript Libraries (in stoke.html)
- **React** 18.2.0 - UI framework
- **React DOM** 18.2.0 - Rendering
- **Babel Standalone** 7.23.5 - JSX transpilation

## Build Targets

```
blocks (iOS App)
    │
    ├── Compile Sources
    │   ├── blocksApp.swift
    │   ├── ContentView.swift
    │   ├── AdMobManager.swift
    │   └── PurchaseManager.swift
    │
    ├── Link Frameworks
    │   ├── SwiftUI.framework
    │   ├── WebKit.framework
    │   ├── GoogleMobileAds (SPM/CocoaPods)
    │   └── RevenueCat (SPM/CocoaPods)
    │
    └── Copy Bundle Resources
        └── stoke.html ← Must be included!
```

## App Lifecycle

```
App Launch
    │
    ├─► blocksApp.init()
    │       │
    │       ├─► AdMobManager.shared.initialize()
    │       └─► PurchaseManager.shared.configure()
    │
    └─► ContentView.body
            │
            ├─► WebViewContainer loads stoke.html
            │       │
            │       └─► React app renders
            │
            ├─► JavaScript bridge injected
            │       │
            │       └─► window.Capacitor.* APIs available
            │
            └─► Game starts
                    │
                    ├─► Game checks isNativePlatform() → true
                    ├─► Loads save data via storage.get()
                    ├─► Requests banner ad
                    └─► Gameplay begins
```

## Threading Model

| Component | Thread |
|-----------|--------|
| SwiftUI views | Main thread |
| WebView rendering | WebKit thread |
| JavaScript execution | WebKit JavaScript thread |
| Message handlers | Main thread (dispatched) |
| AdMob callbacks | Main thread |
| RevenueCat callbacks | Main thread |
| UserDefaults | Main thread |

**Note:** All UI updates must happen on the main thread. The bridge automatically dispatches callbacks to the main queue.

## Security Considerations

1. **JavaScript Bridge**
   - Only specific message handlers registered
   - No arbitrary code execution
   - All messages validated before processing

2. **Storage**
   - UserDefaults is sandboxed to app
   - No sensitive data stored (coins/scores only)

3. **Purchases**
   - RevenueCat handles receipt validation
   - No client-side price manipulation
   - Server-side verification recommended for production

4. **Ads**
   - AdMob SDK handles ad verification
   - No direct user data collection in app code

## Performance Optimization

1. **WebView**
   - HTML/CSS/JS bundled in single file
   - No external resource loading
   - Canvas rendering for game graphics

2. **Ads**
   - Banner loaded once on launch
   - Interstitials preloaded
   - Rewarded ads preloaded on game over

3. **Purchases**
   - Offerings fetched on-demand
   - Cached by RevenueCat SDK

4. **Storage**
   - Batched writes (game saves on score change)
   - UserDefaults is fast for small data

## Future Enhancements

Potential improvements:
- [ ] Analytics integration (Firebase, Amplitude)
- [ ] Push notifications (daily streak reminders)
- [ ] Social features (leaderboards, Game Center)
- [ ] More boosters (hint system, undo)
- [ ] Subscription option (ad-free + daily coins)
- [ ] Native UI for menus (SwiftUI overlays)
- [ ] Haptic feedback
- [ ] App Clips support
- [ ] Widget (show streak)

---

This architecture provides a clean separation between the web-based game and native platform features, allowing the HTML game to run unmodified while gaining full access to iOS monetization and storage capabilities.
