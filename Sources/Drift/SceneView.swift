import AppKit
import Metal
import QuartzCore
import SpriteKit

/// Draws one SpriteKit scene into a transparent Metal layer, driven by a display link that
/// belongs to this view's own screen.
///
/// Why not SKView: with two SKViews on displays with different refresh rates (e.g. a 120 Hz
/// MacBook screen and a 75 Hz monitor), SpriteKit paces both from one clock and the second
/// screen drops to an uneven 15–30 fps. Rendering with SKRenderer from a per-screen display
/// link keeps every screen at its own steady rate.
final class SceneView: NSView {
    private static let device = MTLCreateSystemDefaultDevice()

    let scene: SKScene
    private let renderer: SKRenderer?
    private let queue: MTLCommandQueue?
    private let metalLayer = CAMetalLayer()
    private var link: CADisplayLink?

    /// Stop drawing (screen asleep, locked or Drift paused).
    var isPaused = false { didSet { link?.isPaused = isPaused } }

    /// Called on every frame with the display link's timestamp (used for measuring smoothness).
    var onFrame: ((CFTimeInterval) -> Void)?

    /// Frames per second to aim for; nil = the screen's own refresh rate.
    var frameRateCap: Float? { didSet { applyFrameRate() } }

    init(frame: NSRect, scene: SKScene) {
        self.scene = scene
        renderer = SceneView.device.map { SKRenderer(device: $0) }
        queue = SceneView.device?.makeCommandQueue()
        super.init(frame: frame)
        wantsLayer = true
        layer = metalLayer
        metalLayer.device = SceneView.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.isOpaque = false
        metalLayer.framebufferOnly = true
        metalLayer.maximumDrawableCount = 3
        // Each scene keeps its own screen's size in points and is mapped 1:1 onto this view's
        // drawable. (.resizeFill only works with SKView: under SKRenderer SpriteKit resizes the
        // scene using whichever screen is currently "main", so the other screen's snow got scaled.)
        scene.scaleMode = .fill
        scene.size = frame.size
        renderer?.scene = scene
        renderer?.ignoresSiblingOrder = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate()
        link = nil
        guard window != nil else { return }
        updateDrawableSize()
        // NSView's display link follows the screen this view is on.
        let newLink = displayLink(target: self, selector: #selector(step(_:)))
        newLink.add(to: .main, forMode: .common)
        newLink.isPaused = isPaused
        link = newLink
        applyFrameRate()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize.width > 0, newSize.height > 0 { scene.size = newSize }
        updateDrawableSize()
    }

    /// Stops the display link for good (the view is being thrown away).
    func tearDown() {
        link?.invalidate()
        link = nil
    }

    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? 2
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    /// The screen's own rate, or with a cap the highest even fraction of it that fits
    /// (120 Hz → 60, 75 Hz → 37.5), so frames stay evenly spaced.
    private func applyFrameRate() {
        guard let link else { return }
        let native = Float(window?.screen?.maximumFramesPerSecond ?? 60)
        var target = native
        if let cap = frameRateCap {
            var divisor: Float = 1
            while native / divisor > cap + 0.5 { divisor += 1 }
            target = native / divisor
        }
        link.preferredFrameRateRange = CAFrameRateRange(minimum: target, maximum: native, preferred: target)
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let renderer, let queue else { return }
        onFrame?(link.timestamp)
        renderer.update(atTime: link.timestamp)
        guard let drawable = metalLayer.nextDrawable(), let buffer = queue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderer.render(withViewport: CGRect(origin: .zero, size: metalLayer.drawableSize),
                        commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.present(drawable)
        buffer.commit()
    }
}
