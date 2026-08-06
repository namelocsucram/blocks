import SwiftUI
import UIKit
import WebKit

private final class MagnifierPanDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// Breaks the addTarget retain cycle: pan holds WeakPanTarget strongly,
// but WeakPanTarget holds MagnifierTracker only weakly.
private final class WeakPanTarget: NSObject {
    weak var tracker: MagnifierTracker?

    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        tracker?.handlePan(recognizer)
    }
}

final class MagnifierTracker: NSObject {
    private weak var targetView: UIView?
    private let pan: UIPanGestureRecognizer
    private let panTarget = WeakPanTarget()
    private let delegateProxy = MagnifierPanDelegate()

    let lensDiameter: CGFloat
    let magnification: CGFloat

    private var lastCaptureTime: CFTimeInterval = 0
    private var pendingCapture = false

    var onTouchUpdate: ((CGPoint?) -> Void)?
    var onImageUpdate: ((UIImage?) -> Void)?

    init(targetView: UIView, lensDiameter: CGFloat, magnification: CGFloat) {
        self.targetView = targetView
        self.lensDiameter = lensDiameter
        self.magnification = magnification
        self.pan = UIPanGestureRecognizer()
        super.init()

        panTarget.tracker = self
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = delegateProxy
        pan.addTarget(panTarget, action: #selector(WeakPanTarget.handlePan(_:)))
        targetView.addGestureRecognizer(pan)
    }

    deinit {
        targetView?.removeGestureRecognizer(pan)
    }

    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = targetView else { return }
        let location = recognizer.location(in: view)
        switch recognizer.state {
        case .began, .changed:
            onTouchUpdate?(location)
            requestSnapshot(at: location, in: view)
        default:
            onTouchUpdate?(nil)
            onImageUpdate?(nil)
        }
    }

    private func requestSnapshot(at point: CGPoint, in view: UIView) {
        let now = CACurrentMediaTime()
        guard now - lastCaptureTime >= 1.0 / 30.0, !pendingCapture else { return }
        guard let webView = view as? WKWebView else { return }

        let sampleSize = lensDiameter / max(0.5, magnification)
        let half = sampleSize / 2.0
        let sx = min(max(0, point.x - half), max(0, view.bounds.width - sampleSize))
        let sy = min(max(0, point.y - half), max(0, view.bounds.height - sampleSize))
        let sampleRect = CGRect(x: sx, y: sy, width: sampleSize, height: sampleSize)

        pendingCapture = true
        lastCaptureTime = now

        let config = WKSnapshotConfiguration()
        config.rect = sampleRect

        let diameter = lensDiameter
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self else { return }
            self.pendingCapture = false
            guard let image else { return }
            // takeSnapshot calls back on main thread
            let scaled = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            }
            self.onImageUpdate?(scaled)
        }
    }
}

struct MagnifierOverlay: View {
    var targetView: UIView?
    var lensDiameter: CGFloat = 124
    var magnification: CGFloat = 1.6
    var offset: CGSize = CGSize(width: 0, height: -96)

    @State private var touchPoint: CGPoint? = nil
    @State private var currentImage: UIImage? = nil
    @State private var tracker: MagnifierTracker? = nil

    var body: some View {
        GeometryReader { proxy in
            let targetID = targetView.map { ObjectIdentifier($0) }
            ZStack {
                if let p = touchPoint, let img = currentImage {
                    let cx = min(max(p.x + offset.width, lensDiameter / 2), proxy.size.width - lensDiameter / 2)
                    let cy = min(max(p.y + offset.height, lensDiameter / 2), proxy.size.height - lensDiameter / 2)

                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: lensDiameter, height: lensDiameter)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                        .position(x: cx, y: cy)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.08), value: cx)
                        .animation(.easeOut(duration: 0.08), value: cy)
                }
            }
            .onAppear { attach() }
            .onDisappear { detach() }
            .onChange(of: targetID) { _ in detach(); attach() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func attach() {
        guard tracker == nil, let view = targetView else { return }
        let t = MagnifierTracker(targetView: view, lensDiameter: lensDiameter, magnification: magnification)
        t.onTouchUpdate = { point in
            touchPoint = point
            if point == nil { currentImage = nil }
        }
        t.onImageUpdate = { image in
            currentImage = image
        }
        tracker = t
    }

    private func detach() {
        tracker = nil   // triggers deinit → removeGestureRecognizer
        touchPoint = nil
        currentImage = nil
    }
}

#if DEBUG
struct MagnifierOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            MagnifierOverlay(targetView: nil)
        }
        .previewLayout(.fixed(width: 320, height: 568))
    }
}
#endif
