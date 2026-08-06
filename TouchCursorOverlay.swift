import SwiftUI
import UIKit

private final class TouchCursorGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

private final class TouchCursorTracker: NSObject {
    private weak var targetView: UIView?
    private let pan: UIPanGestureRecognizer
    private let delegateProxy = TouchCursorGestureDelegate()
    private var onUpdate: ((CGPoint?) -> Void)?

    init(targetView: UIView, onUpdate: @escaping (CGPoint?) -> Void) {
        self.targetView = targetView
        self.onUpdate = onUpdate
        self.pan = UIPanGestureRecognizer()
        super.init()

        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = delegateProxy
        pan.addTarget(self, action: #selector(handlePan(_:)))

        targetView.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = targetView else { return }
        let location = recognizer.location(in: view)
        switch recognizer.state {
        case .began, .changed:
            onUpdate?(location)
        default:
            onUpdate?(nil)
        }
    }
}

// A transparent SwiftUI overlay that displays a small cursor above the user's finger
struct TouchCursorOverlay: View {
    // The view we attach our passive gesture to (e.g., WKWebView)
    var targetView: UIView?

    // Vertical offset (in points) to move the cursor above the finger
    var verticalOffset: CGFloat = -72

    // Cursor appearance
    var cursorDiameter: CGFloat = 22

    @State private var touchPoint: CGPoint? = nil
    @State private var tracker: TouchCursorTracker? = nil

    var body: some View {
        GeometryReader { proxy in
            let targetID = targetView.map { ObjectIdentifier($0) }
            ZStack {
                if let p = touchPoint {
                    let x = min(max(p.x, cursorDiameter / 2), proxy.size.width - cursorDiameter / 2)
                    let yRaw = p.y + verticalOffset
                    let y = min(max(yRaw, cursorDiameter / 2), proxy.size.height - cursorDiameter / 2)

                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: cursorDiameter, height: cursorDiameter)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.25), lineWidth: 0.5)
                        )
                        .position(x: x, y: y)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.08), value: x)
                        .animation(.easeOut(duration: 0.08), value: y)
                }
            }
            .onAppear {
                attachIfNeeded()
            }
            .onChange(of: targetID) { _ in
                attachIfNeeded()
            }
        }
        // Ensure this overlay never intercepts touches destined for the WebView
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func attachIfNeeded() {
        guard tracker == nil, let view = targetView else { return }
        tracker = TouchCursorTracker(targetView: view) { newPoint in
            // Update state on main thread
            DispatchQueue.main.async {
                self.touchPoint = newPoint
            }
        }
    }
}

#if DEBUG
import WebKit
struct TouchCursorOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            TouchCursorOverlay(targetView: nil)
        }
        .previewLayout(.fixed(width: 320, height: 568))
    }
}
#endif

