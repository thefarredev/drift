import AppKit
import CoreGraphics

/// A normal app window on screen, in Cocoa global coordinates (origin bottom-left of the main screen).
struct TrackedWindow {
    let id: CGWindowID
    let frame: CGRect
    /// Radius of the rounded top corners snow should follow (0 = square, like app windows).
    var cornerRadius: CGFloat = 0
}

/// Desktop widget geometry. The window list reports widget windows on a 180 pt grid
/// (180×180, 360×180, 720×360) that includes transparent margin around each card;
/// cards sit 10 pt apart, so each window has a 5 pt margin. Cards have rounded corners.
enum WidgetGeometry {
    static let margin: CGFloat = 5
    static let cornerRadius: CGFloat = 20
    /// Snow sits this much into the card's top edge so no hairline gap shows.
    static let sink: CGFloat = 1
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
    /// Let snow settle on desktop widgets and desktop file icons too.
    var includeDesktopItems = true { didSet { if !includeDesktopItems { desktopIcons = [] } } }
    /// Desktop file icons from Finder (top part of each icon), refreshed every few seconds.
    private var desktopIcons: [TrackedWindow] = []
    private var iconTimer: Timer?
    private var iconFetchRunning = false
    private var iconBackoffUntil = Date.distantPast
    private let iconQueue = DispatchQueue(label: "Drift.desktopIcons", qos: .utility)
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
        fetchDesktopIcons()
        iconTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.fetchDesktopIcons()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        iconTimer?.invalidate()
        iconTimer = nil
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
                // The window includes a little transparent margin around the widget card itself.
                var card = frame.insetBy(dx: WidgetGeometry.margin, dy: WidgetGeometry.margin)
                card.size.height -= WidgetGeometry.sink
                frames[id] = card
                if let old = lastFrames[id], old != card { moved.append(id) }
                widgets.append(TrackedWindow(id: id, frame: card, cornerRadius: WidgetGeometry.cornerRadius))
                continue
            }
            frames[id] = frame
            if let old = lastFrames[id], old != frame { moved.append(id) }
            result.append(TrackedWindow(id: id, frame: frame))
        }
        // Widgets are behind every app window, and desktop icons behind the widgets.
        result += widgets
        if includeDesktopItems {
            for icon in desktopIcons {
                frames[icon.id] = icon.frame
                result.append(icon)
            }
        }

        // Windows that disappeared (closed or minimised) also drop their snow.
        for id in lastFrames.keys where frames[id] == nil { moved.append(id) }

        windows = result
        lastFrames = frames
        if !moved.isEmpty { onWindowsMoved?(moved) }
    }

    // MARK: Desktop icons

    /// Asks Finder (off the main thread) where the desktop icons are. Fails quietly when
    /// Finder can't be asked (e.g. Automation permission denied) and tries again later.
    private func fetchDesktopIcons() {
        guard includeDesktopItems, !iconFetchRunning, Date() >= iconBackoffUntil else { return }
        iconFetchRunning = true
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        iconQueue.async { [weak self] in
            let icons = WindowTracker.readDesktopIcons(mainHeight: mainHeight)
            DispatchQueue.main.async {
                guard let self else { return }
                self.iconFetchRunning = false
                if let icons {
                    self.desktopIcons = self.includeDesktopItems ? icons : []
                } else {
                    self.desktopIcons = []
                    self.iconBackoffUntil = Date().addingTimeInterval(60)
                }
            }
        }
    }

    /// Icon positions from Finder: "iconSize;x,y;x,y…" (x, y = icon centre, top-left origin).
    /// Returns nil on any error.
    private static func readDesktopIcons(mainHeight: CGFloat) -> [TrackedWindow]? {
        // Desktop icons hidden in Finder's settings: nothing to settle on.
        if UserDefaults(suiteName: "com.apple.finder")?.object(forKey: "CreateDesktop") as? Bool == false { return [] }
        let script = """
        tell application "Finder"
            set out to (icon size of icon view options of window of desktop) as text
            repeat with p in (get desktop position of every item of desktop)
                set out to out & ";" & ((item 1 of p) as text) & "," & ((item 2 of p) as text)
            end repeat
            return out
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        // Don't let a stuck Finder hold things up.
        let deadline = Date().addingTimeInterval(4)
        while process.isRunning && Date() < deadline { usleep(20_000) }
        if process.isRunning { process.terminate(); return nil }
        guard process.terminationStatus == 0,
              let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return nil }

        var parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ";")
        guard let first = parts.first, let size = Double(first) else { return nil }
        parts.removeFirst()
        // The icon image is a bit smaller than its slot; the snow ledge spans the middle of it.
        let iconSide = CGFloat(size)
        let ledge = iconSide * 0.72
        var icons: [TrackedWindow] = []
        for part in parts {
            let xy = part.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard xy.count == 2 else { continue }
            let cx = CGFloat(xy[0]), cy = CGFloat(xy[1])
            let top = mainHeight - (cy - iconSide * 0.42)     // Cocoa y of the icon image's top
            let frame = CGRect(x: cx - ledge / 2, y: top - iconSide * 0.8, width: ledge, height: iconSide * 0.8)
            // A stable ID from the position: when an icon moves, its old snow falls off.
            let id = CGWindowID(0x4000_0000)
                | (CGWindowID(UInt32(truncatingIfNeeded: Int(xy[0]) + 8192) & 0x7FFF) << 15)
                | CGWindowID(UInt32(truncatingIfNeeded: Int(xy[1]) + 8192) & 0x7FFF)
            icons.append(TrackedWindow(id: id, frame: frame))
        }
        return icons
    }

    // MARK: Widgets

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
