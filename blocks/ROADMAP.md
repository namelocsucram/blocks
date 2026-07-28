# STOKE Improvement Roadmap

This roadmap turns the project review into implementation phases. The goal is to stabilize the current WebKit app first, then replace prototype pieces with production-ready systems.

## Phase 1: Stabilize the Current Shell

Status: In progress

Focus: make the app's current native wrapper reliable without needing final production credentials.

- [x] Keep SDK configuration owned by Swift, not JavaScript.
- [x] Prevent purchase calls from touching RevenueCat before it is configured.
- [x] Make bridge callbacks safer by JSON-encoding dynamic values before injecting JavaScript.
- [x] Clean up `NotificationCenter` observers when bridge objects deallocate.
- [x] Remove duplicate initialization from SwiftUI view appearance.
- [x] Document which monetization flows are stubbed versus production-ready.

Phase 1 note: the native JavaScript bridge is disabled by default so the simulator runs the game through browser fallbacks. Re-enable native messaging only after Phase 2/3 replace the bridge with a safer request/response transport.

## Phase 2: Implement Production AdMob

Status: Not started

Focus: replace placeholder ad handling with Google Mobile Ads SDK behavior.

- [ ] Add an active `AdMobManager` using the installed GoogleMobileAds APIs.
- [ ] Initialize Mobile Ads once at app launch.
- [ ] Show and remove banner ads without covering game controls.
- [ ] Load/present interstitial ads and report dismissal/failure to JavaScript.
- [ ] Load/present rewarded ads and grant rewards only from native reward callbacks.
- [ ] Add UMP consent flow before ad requests.

## Phase 3: Finish RevenueCat Purchases

Status: Not started

Focus: make coin purchases safe, testable, and App Store ready.

- [ ] Replace placeholder RevenueCat API key with the production `appl_...` key.
- [ ] Verify App Store Connect products and RevenueCat offerings for `coins_100`, `coins_350`, `coins_800`, and `coins_2000`.
- [ ] Return purchase results from Swift with package identifiers and failure reasons.
- [ ] Grant coins only after native purchase success.
- [ ] Decide whether restore purchases applies to the coin product type and document that choice.

## Phase 4: Bundle the Web App for Production

Status: Not started

Focus: remove CDN/runtime compilation from the app bundle.

- [ ] Move game logic from inline HTML into source modules.
- [ ] Build React/JSX ahead of time with a bundler such as Vite or esbuild.
- [ ] Bundle React, CSS, and game assets locally.
- [ ] Load built assets from the app bundle without network dependency.
- [ ] Remove `babel-standalone` and `type="text/babel"` from shipped HTML.

## Phase 5: Test Core Game Logic

Status: Not started

Focus: reduce regressions in the puzzle economy and daily systems.

- [ ] Extract placement, line clear, piece draw, streak, goals, and coin economy logic into testable modules.
- [ ] Add unit coverage for blocked-board detection and line clear scoring.
- [ ] Add save-data migration tests.
- [ ] Add smoke UI automation for launch, drag/place, game over, and coin shop open.

## Phase 6: Production Readiness

Status: Not started

Focus: prepare the app for TestFlight and App Review.

- [ ] Add privacy manifest and review App Privacy nutrition labels.
- [ ] Verify ATT/consent messaging and privacy policy URL.
- [ ] Test on small iPhone, large iPhone, and iPad if supported.
- [ ] Archive a Release build and run sandbox purchase/ad tests on a real device.
- [ ] Update README, setup docs, and checklist to match the shipped implementation.
