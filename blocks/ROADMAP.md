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

Phase 1 note: the broad native JavaScript bridge was disabled to stop WebKit message-handler crashes. Phase 3 attempted a narrower storage-only bridge, but it has been disabled again after simulator instability.

## Phase 2: Implement Production AdMob

Status: Complete

Focus: replace placeholder ad handling with Google Mobile Ads SDK behavior.

- [x] Add active AdMob bridge code using the installed GoogleMobileAds APIs.
- [x] Initialize Mobile Ads once before ad requests.
- [x] Show and remove banner ads through the native bridge.
- [x] Load/present interstitial ads through the native bridge.
- [x] Load/present rewarded ads and grant rewards only from native reward callbacks.
- [ ] Add UMP consent flow before ad requests.
- [ ] Verify banner layout and full-screen ad behavior on a real device with AdMob test-device settings.

## Phase 3: Finish RevenueCat Purchases

Status: In progress

Focus: make coin purchases safe, testable, and App Store ready.

- [x] Split native bridge into explicit modes: disabled, storage-only, and storage plus monetization.
- [ ] Re-enable native storage without activating AdMob or RevenueCat message handlers. Current storage-only implementation is flag-gated after a runtime crash.
- [ ] Replace placeholder RevenueCat API key with the production `appl_...` key.
- [ ] Verify App Store Connect products and RevenueCat offerings for `coins_100`, `coins_350`, `coins_800`, and `coins_2000`.
- [ ] Return purchase results from Swift with package identifiers and failure reasons.
- [ ] Grant coins only after native purchase success.
- [ ] Decide whether restore purchases applies to the coin product type and document that choice.

## Phase 4: Bundle the Web App for Production

Status: Not started

Focus: remove CDN/runtime compilation from the app bundle.

- [x] Move game logic from inline HTML into source modules.
- [x] Build React/JSX ahead of time with esbuild.
- [x] Bundle React and game code locally.
- [x] Load built app code from the app bundle without CDN script dependencies.
- [x] Remove `babel-standalone` and `type="text/babel"` from shipped HTML.

## Phase 5: Test Core Game Logic

Status: In progress

Focus: reduce regressions in the puzzle economy and daily systems.

- [x] Extract placement, line clear, piece draw, blocked-board, and scoring logic into a testable module.
- [x] Add unit coverage for blocked-board detection and line clear scoring.
- [ ] Extract streak, goals, and coin economy logic into testable modules.
- [x] Add save-data migration tests.
- [x] Add smoke UI automation for launch, drag/place, coin shop open, game over, and rewarded-rescue flow.

## Phase 6: Production Readiness

Status: In progress

Focus: prepare the app for TestFlight and App Review.

- [x] Add first-party privacy manifest.
- [ ] Review App Privacy nutrition labels against final AdMob, UMP, RevenueCat, and first-party storage behavior.
- [ ] Verify ATT/consent messaging and privacy policy URL.
- [ ] Test on small iPhone, large iPhone, and iPad if supported.
- [ ] Archive a Release build and run sandbox purchase/ad tests on a real device.
- [ ] Update README, setup docs, and checklist to match the shipped implementation.
