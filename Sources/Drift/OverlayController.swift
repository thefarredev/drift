import AppKit
import SpriteKit
import IOKit.pwr_mgt

/// Creates one transparent, click-through window per screen and keeps them in sync
/// with screen changes, power state and the current weather.
final class OverlayController {
    let tracker = WindowTracker()
    private var overlays: [(window: NSPanel, view: SKView, scene: WeatherOverlayScene)] = []

    var weather: WeatherScene = .snow { didSet { applySettings() } }
    var intensity: Intensity = .medium { didSet { applySettings() } }
    var wind: CGFloat = -8 { didSet { applySettings() } }
    var settle = true { didSet { applySettings() } }
    var paused = false { didSet { applySettings() } }
    var moments: MomentFrequency = .sometimes { didSet { applySettings() } }
    var awayMinutes = 5

    private var awayTimer: Timer?
    private var isAway = false

    init() {
        tracker.onWindowsMoved = { [weak self] ids in
            self?.overlays.forEach { $0.scene.shakeOff(windowIDs: ids) }
        }
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                           object: nil, queue: .main) { [weak self] _ in self?.rebuild() }
        center.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                           object: nil, queue: .main) { [weak self] _ in self?.applySettings() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.applySettings() }
        // Stop drawing while the screen sleeps or is locked.
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.overlays.forEach { $0.view.isPaused = true }
            }
        }
        // Switching Spaces (e.g. swiping into a full-screen app): bring the overlay along.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.overlays.forEach { $0.window.orderFrontRegardless() }
            }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.applySettings()
            }
        }
    }

    func start() {
        rebuild()
        tracker.start()
        awayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkAway()
        }
    }

    // MARK: - Funny moments

    func sendCrew() { overlays.forEach { $0.scene.moments.sendCrew() } }
    func sendPlough() { overlays.forEach { $0.scene.moments.sendPlough() } }
    func buildSnowman() {
        // One snowman, on whichever screen has room.
        for overlay in overlays.shuffled() where overlay.scene.moments.buildSnowman() { return }
    }
    func demoBury() { overlays.forEach { $0.scene.moments.demoBury() } }

    /// Fills the screen with snow while you're away (only when it's snowing), and
    /// sends the dig-out crew as soon as you touch the keyboard or mouse again.
    private func checkAway() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)

        if isAway {
            if idle < 2 {
                isAway = false
                overlays.forEach { $0.scene.moments.returnFromAway() }
            }
            return
        }
        guard awayMinutes > 0, weather == .snow, settle, !paused,
              idle > Double(awayMinutes * 60), !Self.isWatchingVideo() else { return }
        isAway = true
        overlays.forEach { $0.scene.moments.startBurying(minutes: 6) }
    }

    /// Video players keep the display awake; don't bury someone watching a film.
    private static func isWatchingVideo() -> Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Any] else { return false }
        return (dict["PreventUserIdleDisplaySleep"] as? Int ?? 0) > 0
    }

    func clearSnow() { overlays.forEach { $0.scene.clearAllSnow() } }

    private func rebuild() {
        overlays.forEach { $0.window.orderOut(nil) }
        overlays.removeAll()

        for screen in NSScreen.screens {
            // A non-activating panel is what macOS allows to float above full-screen apps
            // (together with .fullScreenAuxiliary below). A plain window stays on the desktop Space.
            let window = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            window.isFloatingPanel = true
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true          // clicks go straight through to apps below
            window.level = .statusBar                 // above app windows (also full-screen ones), below menus
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false

            let view = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.allowsTransparency = true
            view.preferredFramesPerSecond = 60
            view.ignoresSiblingOrder = true

            // visibleFrame excludes the Dock and menu bar; its bottom is the top of the Dock.
            let scene = WeatherOverlayScene(screenFrame: screen.frame,
                                            dockY: screen.visibleFrame.minY,
                                            usableTopY: screen.visibleFrame.maxY)
            scene.tracker = tracker
            view.presentScene(scene)

            window.contentView = view
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            overlays.append((window, view, scene))
        }
        applySettings()
    }

    private func applySettings() {
        let calm = ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let rate = intensity.spawnRate * (calm ? 0.35 : 1)

        for overlay in overlays {
            overlay.scene.weather = weather
            overlay.scene.spawnRate = rate
            overlay.scene.wind = wind
            overlay.scene.settle = settle
            overlay.scene.moments.frequency = moments
            overlay.view.isPaused = paused
            overlay.view.preferredFramesPerSecond = (calm || weather == .clear) ? 30 : 60
            overlay.window.alphaValue = paused ? 0 : 1
        }
    }
}
