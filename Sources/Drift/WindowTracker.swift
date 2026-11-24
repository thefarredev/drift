import AppKit
import CoreGraphics

/// A normal app window on screen, in Cocoa global coordinates (origin bottom-left of the main screen).
struct TrackedWindow {
    let id: CGWindowID
    let frame: CGRect
}

/// Reads the position of every visible app window a few times per second, plus desktop
/// widgets (placed behind all app windows).
///
/// Only window *bounds* are read (kCGWindowBounds). That needs no Screen Recording
/// permission; only window titles and contents would.
final class WindowTracker {
    /// Front-to-back order, like the system reports it: app windows first, then widgets
    /// (which sit on the desktop, behind every app window).
    private(set) var windows: [TrackedWindow] = []
    /// Let snow settle on desktop widgets too.
    var includeDesktopItems = true
    /// Called with the IDs of windows that moved or resized since the last poll.
    var onWindowsMoved: (([CGWindowID]) -> Void)?

    private var timer: Timer?
    private var lastFrames: [CGWindowID: CGRect] = [:]
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func start(interval: TimeInterval = 0.2) {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly],
                                                    kCGNullWindowID) as? [[String: Any]] else { return }
        // Height of the main (menu bar) screen: CG uses a top-left origin, Cocoa a bottom-left one.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0

        var result: [TrackedWindow] = []
        var widgets: [TrackedWindow] = []
        var moved: [CGWindowID] = []
        var frames: [CGWindowID: CGRect] = [:]

        for entry in info {
            guard let layer = entry[kCGWindowLayer as String] as? Int,
                  let pid = entry[kCGWindowOwnerPID as String] as? Int32, pid != ownPID else { continue }
            // Layer 0 = normal app windows (skips the menu bar, Dock, overlays, etc.).
            // Desktop widgets live far below, at the desktop level, owned by Notification Center.
            let isWidget = layer < 0 && includeDesktopItems && isWidgetOwner(pid)
            guard layer == 0 || isWidget,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha < 0.1 { continue }
            if cgBounds.width < 60 || cgBounds.height < 40 { continue }
            // Notification Center's other desktop-level surfaces are huge; widgets are at most 720×360.
            if isWidget && (cgBounds.width > 900 || cgBounds.height > 600) { continue }

            let frame = CGRect(x: cgBounds.minX,
                               y: mainHeight - cgBounds.maxY,
                               width: cgBounds.width,
                               height: cgBounds.height)
            if isWidget {
                // The window includes a little transparent margin around the widget itself.
                let inset = frame.insetBy(dx: 5, dy: 5)
                frames[id] = inset
                if let old = lastFrames[id], old != inset { moved.append(id) }
                widgets.append(TrackedWindow(id: id, frame: inset))
                continue
            }
            frames[id] = frame
            if let old = lastFrames[id], old != frame { moved.append(id) }
            result.append(TrackedWindow(id: id, frame: frame))
        }
        // Widgets are behind every app window, so they go after them in front-to-back order.
        result += widgets

        // Windows that disappeared (closed or minimised) also drop their snow.
        for id in lastFrames.keys where frames[id] == nil { moved.append(id) }

        windows = result
        lastFrames = frames
        if !moved.isEmpty { onWindowsMoved?(moved) }
    }

    private var widgetOwners: [pid_t: Bool] = [:]

    /// Desktop widgets are drawn by Notification Center.
    private func isWidgetOwner(_ pid: pid_t) -> Bool {
        if let known = widgetOwners[pid] { return known }
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        let yes = bundle == "com.apple.notificationcenterui" || bundle.hasPrefix("com.apple.chrono")
        widgetOwners[pid] = yes
        return yes
    }

    /// True if the point (Cocoa global coords) is covered by a window in front of `index`.
    func isCovered(_ p: CGPoint, inFrontOf index: Int) -> Bool {
        guard index > 0 else { return false }
        for i in 0..<index where windows[i].frame.contains(p) { return true }
        return false
    }
}
