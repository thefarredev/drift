import AppKit
import SpriteKit

/// One falling particle (a snowflake or a raindrop). All positions are in Cocoa global coordinates.
private struct Particle {
    var pos: CGPoint
    var vel: CGVector
    var size: CGFloat
    var phase: CGFloat
    var isRain: Bool
    var settles: Bool       // false for snow thrown by workers, so it doesn't land right back
    let node: SKSpriteNode
}

/// Snow that has settled on top of one window (or on the ground above the Dock).
/// Stored as a height per column, like a tiny 1D heightmap.
final class Pile {
    static let columnWidth: CGFloat = 3
    let windowID: CGWindowID
    var originX: CGFloat          // global x of column 0
    var topY: CGFloat             // global y of the surface the snow sits on
    var heights: [CGFloat]
    let maxHeight: CGFloat
    let node = SKShapeNode()
    /// How far below `topY` each column's base sits: 0 on a flat top, more along rounded corners.
    let baseDrop: [CGFloat]
    /// Most snow each column can hold (thin near edges; none where a rounded corner is too steep).
    private let caps: [CGFloat]
    /// Columns at each end whose cap is below maxHeight (only those need clamping).
    private let edgeColumns: Int

    init(windowID: CGWindowID, originX: CGFloat, width: CGFloat, topY: CGFloat, maxHeight: CGFloat,
         cornerRadius: CGFloat = 0) {
        self.windowID = windowID
        self.originX = originX
        self.topY = topY
        self.maxHeight = maxHeight
        let count = max(1, Int(width / Pile.columnWidth))
        self.heights = Array(repeating: 0, count: count)

        var drops = Array(repeating: CGFloat(0), count: count)
        var caps = Array(repeating: maxHeight, count: count)
        let r = min(cornerRadius, width / 2)
        for c in 0..<count {
            // Distance from the nearer side edge, at the column's centre.
            let d = min((CGFloat(c) + 0.5) * Pile.columnWidth, width - (CGFloat(c) + 0.5) * Pile.columnWidth)
            if r > 0 {
                guard d < r else { continue }
                // Follow the corner arc down; the slope gets steeper toward the edge.
                let u = r - d                                   // horizontal distance into the arc
                let rise = (r * r - u * u).squareRoot()
                drops[c] = r - rise
                let angle = atan2(u, rise) * 180 / .pi          // 0° = flat, 90° = vertical
                // Snow thins as the arc steepens and slides off beyond ~55°.
                let hold = max(0, 1 - angle / 55)
                caps[c] = maxHeight * hold * hold
            } else {
                // Square edges stay thin so the pile looks rounded, like real snow on a ledge.
                let edgeFalloff: CGFloat = 4
                let i = CGFloat(Int(d / Pile.columnWidth))
                if i < edgeFalloff { caps[c] = maxHeight * (i + 1) / (edgeFalloff + 1) }
            }
        }
        baseDrop = drops
        self.caps = caps
        edgeColumns = min(count, (caps.firstIndex { $0 >= maxHeight } ?? count))
        node.fillColor = NSColor(white: 1, alpha: 0.96)
        node.strokeColor = NSColor(white: 0.85, alpha: 0.6)
        node.lineWidth = 0.5
        node.zPosition = 1
    }

    var width: CGFloat { CGFloat(heights.count) * Pile.columnWidth }

    func column(forX x: CGFloat) -> Int? {
        let c = Int((x - originX) / Pile.columnWidth)
        return heights.indices.contains(c) ? c : nil
    }

    func surfaceY(atColumn c: Int) -> CGFloat { topY - baseDrop[c] + heights[c] }

    /// Add one flake's worth of snow, letting it slide sideways if the slope is too steep.
    func add(atColumn start: Int, amount: CGFloat) {
        var c = start
        // Simple avalanche: roll downhill while a neighbour is clearly lower.
        for _ in 0..<6 {
            let left = c > 0 ? heights[c - 1] : .greatestFiniteMagnitude
            let right = c < heights.count - 1 ? heights[c + 1] : .greatestFiniteMagnitude
            let lowest = min(left, right)
            if heights[c] - lowest > 1.6 {
                c = (left < right) ? c - 1 : c + 1
            } else { break }
        }
        heights[c] = min(caps[c], heights[c] + amount)
        // Keep the thin edges (and steep rounded corners) thin.
        for i in 0..<edgeColumns {
            let j = heights.count - 1 - i
            heights[i] = min(heights[i], caps[i])
            heights[j] = min(heights[j], caps[j])
        }
    }

    var isEmpty: Bool { !heights.contains { $0 > 0.2 } }
}

/// The SpriteKit scene drawn on one screen's transparent overlay.
final class WeatherOverlayScene: SKScene {
    var screenFrame: CGRect          // global frame of the screen this scene covers
    var dockY: CGFloat               // global y of the top of the Dock / bottom of usable area
    var usableTopY: CGFloat          // global y just below the menu bar
    /// Where snow lands at the bottom: on the Dock normally, the very bottom of the screen
    /// when a full-screen app hides the Dock.
    private var groundY: CGFloat { isFullScreen ? screenFrame.minY : dockY }
    private var isFullScreen = false
    weak var tracker: WindowTracker?

    var weather: WeatherScene = .snow
    var spawnRate: Double = 45       // per 1000pt of width, per second
    var settle = true
    var wind: CGFloat = -8           // sideways drift in pt/s

    private var particles: [Particle] = []
    private var pool: [SKSpriteNode] = []
    private(set) var piles: [CGWindowID: Pile] = [:]
    private var lastTime: TimeInterval = 0
    private var spawnAccumulator: Double = 0
    private var redrawTimer: TimeInterval = 0
    private var elapsed: CGFloat = 0
    let groundID: CGWindowID = 0
    /// Workers, snow plough, snowmen and the "buried while you're away" layer.
    private(set) lazy var moments = MomentsDirector(scene: self)

    private lazy var flakeTexture = WeatherOverlayScene.makeFlakeTexture()
    private lazy var dropTexture = WeatherOverlayScene.makeDropTexture()

    init(screenFrame: CGRect, dockY: CGFloat, usableTopY: CGFloat) {
        self.screenFrame = screenFrame
        self.dockY = dockY
        self.usableTopY = usableTopY
        super.init(size: screenFrame.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Public

    /// A window moved, resized or closed: its snow slides off and falls.
    func shakeOff(windowIDs: [CGWindowID]) {
        for id in windowIDs {
            guard let pile = piles.removeValue(forKey: id) else { continue }
            for (c, h) in pile.heights.enumerated() where h > 0.5 {
                // One falling clump per few columns, sized by how deep the snow was.
                guard c % 2 == 0 else { continue }
                let x = pile.originX + CGFloat(c) * Pile.columnWidth
                let clumps = min(3, Int(h / 3) + 1)
                for _ in 0..<clumps {
                    spawn(at: CGPoint(x: x + .random(in: -2...2), y: pile.topY + .random(in: 0...h)),
                          velocity: CGVector(dx: .random(in: -25...25), dy: .random(in: -10...30)),
                          rain: false, size: .random(in: 2.5...4.5))
                }
            }
            pile.node.removeFromParent()
        }
    }

    /// Is this point on a pile hidden behind a window that is in front of the pile's window?
    func isCovered(_ globalPoint: CGPoint, on pile: Pile) -> Bool {
        guard pile.windowID != groundID, let windows = tracker?.windows,
              let index = windows.firstIndex(where: { $0.id == pile.windowID }) else { return false }
        return tracker?.isCovered(globalPoint, inFrontOf: index) ?? false
    }

    /// Converts a global point into this scene's coordinates.
    func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - screenFrame.minX, y: p.y - screenFrame.minY) }

    /// The ground pile, created on demand (only while snow can settle).
    func ground() -> Pile? { settle ? groundPile() : nil }

    func clearAllSnow() {
        for pile in piles.values { pile.node.removeFromParent() }
        piles.removeAll()
    }

    // MARK: - Mouse

    /// Cursor position (global) and smoothed velocity in pt/s. The overlay never takes clicks;
    /// it just reads where the pointer is, which needs no permission.
    private(set) var cursor = CGPoint(x: -1000, y: -1000)
    private(set) var cursorVel = CGVector.zero
    var cursorSpeed: CGFloat { hypot(cursorVel.dx, cursorVel.dy) }
    private var cursorPuffBudget: CGFloat = 0

    private func updateCursor(dt: CGFloat) {
        let now = NSEvent.mouseLocation
        guard screenFrame.insetBy(dx: -30, dy: -30).contains(now) else {
            cursor = CGPoint(x: -1000, y: -1000)
            cursorVel = .zero
            return
        }
        if cursor.x > -999, dt > 0 {
            let raw = CGVector(dx: (now.x - cursor.x) / dt, dy: (now.y - cursor.y) / dt)
            cursorVel = CGVector(dx: cursorVel.dx * 0.6 + raw.dx * 0.4, dy: cursorVel.dy * 0.6 + raw.dy * 0.4)
        }
        cursor = now
        if settle { pushSnow(dt: dt) }
    }

    /// Moving the pointer through settled snow pushes it aside softly, with a little puff.
    private func pushSnow(dt: CGFloat) {
        let speed = cursorSpeed
        guard speed > 25 else { return }
        cursorPuffBudget = min(6, cursorPuffBudget + dt * 40)
        let radius: CGFloat = 12
        let dir: CGFloat = cursorVel.dx >= 0 ? 1 : -1
        for pile in piles.values {
            guard cursor.x > pile.originX - radius, cursor.x < pile.originX + pile.width + radius,
                  let c = pile.column(forX: cursor.x) else { continue }
            let surface = pile.surfaceY(atColumn: c)
            guard cursor.y > pile.topY - 3, cursor.y < surface + 4, pile.heights[c] > 0.3 else { continue }
            if isCovered(CGPoint(x: cursor.x, y: pile.topY + 1), on: pile) { continue }

            let reach = Int(radius / Pile.columnWidth)
            let strength = min(0.5, speed / 1600)
            var moved: CGFloat = 0
            for i in max(0, c - reach)...min(pile.heights.count - 1, c + reach) {
                let f = 1 - CGFloat(abs(i - c)) / CGFloat(reach + 1)
                let take = pile.heights[i] * strength * f
                pile.heights[i] -= take
                moved += take
            }
            // Half slides ahead of the pointer, half puffs up into the air.
            let ahead = c + Int(dir) * (reach + 2)
            if pile.heights.indices.contains(ahead) {
                pile.add(atColumn: ahead, amount: moved * 0.5)
            }
            if moved > 0.8, cursorPuffBudget >= 1 {
                cursorPuffBudget -= 1
                spawn(at: CGPoint(x: cursor.x, y: surface),
                      velocity: CGVector(dx: cursorVel.dx * 0.25 + .random(in: -15...15), dy: .random(in: 30...70)),
                      rain: false, size: .random(in: 1.6...3))
            }
        }
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20))
        lastTime = currentTime
        elapsed += dt

        updateFullScreenState()
        spawnNew(dt: dt)
        step(dt: dt)
        melt(dt: dt)
        updateCursor(dt: dt)
        moments.update(dt: dt)

        redrawTimer += Double(dt)
        if redrawTimer > 0.12 {
            redrawTimer = 0
            syncPilesWithWindows()
            redrawPiles()
        }
    }

    /// A window that covers the whole screen means a full-screen app (its own Space, Dock hidden).
    private func updateFullScreenState() {
        let full = (tracker?.windows ?? []).contains { w in
            w.frame.minX <= screenFrame.minX + 2 && w.frame.maxX >= screenFrame.maxX - 2 &&
            w.frame.minY <= screenFrame.minY + 2 && w.frame.maxY >= screenFrame.maxY - 2
        }
        guard full != isFullScreen else { return }
        isFullScreen = full
        if full {
            // The ground pile would float mid-screen at Dock height: let it fall to the bottom.
            shakeOff(windowIDs: [groundID])
        } else if let ground = piles.removeValue(forKey: groundID) {
            // Back from full screen: the bottom-of-screen pile would sit behind the Dock.
            ground.node.removeFromParent()
        }
    }

    private func spawnNew(dt: CGFloat) {
        guard weather != .clear else { return }
        spawnAccumulator += spawnRate * Double(screenFrame.width / 1000) * Double(dt)
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            let x = CGFloat.random(in: screenFrame.minX - 40...screenFrame.maxX + 40)
            let y = screenFrame.maxY + 10
            if weather == .rain {
                spawn(at: CGPoint(x: x, y: y),
                      velocity: CGVector(dx: wind * 4, dy: -CGFloat.random(in: 700...950)),
                      rain: true, size: .random(in: 0.8...1.4))
            } else {
                let size = CGFloat.random(in: 1.5...4.2)
                // Bigger flakes fall a little faster, which gives a sense of depth.
                spawn(at: CGPoint(x: x, y: y),
                      velocity: CGVector(dx: wind, dy: -(25 + size * 14 + CGFloat.random(in: 0...15))),
                      rain: false, size: size)
            }
        }
    }

    func spawn(at p: CGPoint, velocity: CGVector, rain: Bool, size: CGFloat, settles: Bool = true) {
        let node = pool.popLast() ?? SKSpriteNode()
        node.texture = rain ? dropTexture : flakeTexture
        if rain {
            node.size = CGSize(width: size, height: size * 14)
            node.zRotation = atan2(velocity.dx, -velocity.dy)
            node.alpha = 0.45
        } else {
            node.size = CGSize(width: size * 2, height: size * 2)
            node.zRotation = 0
            node.alpha = 0.75 + size / 20
        }
        node.zPosition = 2
        node.position = CGPoint(x: p.x - screenFrame.minX, y: p.y - screenFrame.minY)
        if node.parent == nil { addChild(node) }
        particles.append(Particle(pos: p, vel: velocity, size: size,
                                  phase: .random(in: 0...(2 * .pi)), isRain: rain, settles: settles, node: node))
    }

    private func step(dt: CGFloat) {
        let windows = settle ? (tracker?.windows ?? []) : []
        var i = 0
        while i < particles.count {
            var p = particles[i]
            let oldY = p.pos.y

            if p.isRain {
                p.pos.x += p.vel.dx * dt
                p.pos.y += p.vel.dy * dt
            } else {
                // Gravity toward terminal velocity, plus a gentle side-to-side sway.
                let terminal = -(25 + p.size * 14)
                p.vel.dy += (terminal - p.vel.dy) * min(1, dt * 2)
                p.vel.dx += (wind - p.vel.dx) * min(1, dt * 1.5)
                // The mouse gently blows flakes along as it passes.
                if cursorSpeed > 30 {
                    let dx = p.pos.x - cursor.x, dy = p.pos.y - cursor.y
                    let d2 = dx * dx + dy * dy
                    if d2 < 50 * 50 {
                        let f = 1 - d2.squareRoot() / 50
                        p.vel.dx += cursorVel.dx * f * dt * 5
                        p.vel.dy += cursorVel.dy * f * dt * 5
                    }
                }
                let sway = sin(elapsed * 1.3 + p.phase) * (6 + p.size * 2)
                p.pos.x += (p.vel.dx + sway) * dt
                p.pos.y += p.vel.dy * dt
            }

            if land(&p, oldY: oldY, windows: windows) || p.pos.y < screenFrame.minY - 20 {
                recycle(at: i)
                continue
            }

            p.node.position = CGPoint(x: p.pos.x - screenFrame.minX, y: p.pos.y - screenFrame.minY)
            particles[i] = p
            i += 1
        }
    }

    /// Returns true if the particle hit something (and should disappear).
    private func land(_ p: inout Particle, oldY: CGFloat, windows: [TrackedWindow]) -> Bool {
        guard p.settles else { return false }
        // 1) Window tops, front to back. A flake lands on the first top edge it crosses
        //    that isn't hidden behind another window.
        for (index, w) in windows.enumerated() {
            let top = w.frame.maxY
            guard p.pos.x > w.frame.minX + 6, p.pos.x < w.frame.maxX - 6 else { continue }
            let pile = pileFor(window: w)
            guard let c = pile?.column(forX: p.pos.x) else { continue }
            let surface = pile!.surfaceY(atColumn: c)
            guard oldY >= surface, p.pos.y <= surface else { continue }
            if tracker?.isCovered(CGPoint(x: p.pos.x, y: top + 1), inFrontOf: index) == true { continue }
            if !p.isRain { pile!.add(atColumn: c, amount: 0.35 + p.size * 0.12) }
            return true
        }
        // 2) The ground (top of the Dock). Snow lands on top of what has already piled up.
        if settle, !p.isRain, let ground = groundPile(), let c = ground.column(forX: p.pos.x) {
            if p.pos.y <= ground.surfaceY(atColumn: c) {
                ground.add(atColumn: c, amount: 0.25 + p.size * 0.08)
                return true
            }
            return false
        }
        return p.isRain && p.pos.y <= groundY
    }

    private func recycle(at i: Int) {
        let node = particles[i].node
        node.removeFromParent()
        pool.append(node)
        particles.swapAt(i, particles.count - 1)
        particles.removeLast()
    }

    private func melt(dt: CGFloat) {
        // Snow melts slowly, faster when it isn't snowing anymore.
        let rate: CGFloat = weather == .snow ? 0.01 : (weather == .rain ? 0.6 : 0.15)
        for pile in piles.values {
            for c in pile.heights.indices where pile.heights[c] > 0 {
                pile.heights[c] = max(0, pile.heights[c] - rate * dt)
            }
        }
    }

    // MARK: - Piles

    private func pileFor(window w: TrackedWindow) -> Pile? {
        // Only windows whose top edge is on this screen.
        guard w.frame.maxY > screenFrame.minY, w.frame.maxY <= screenFrame.maxY else { return nil }
        // Maximised and full-screen windows reach the top of the screen. Snow sitting there
        // looks stuck to the menu bar, so it falls straight through those windows instead.
        guard w.frame.maxY < usableTopY - 4 else { return nil }
        if let existing = piles[w.id] { return existing }
        let pile = Pile(windowID: w.id, originX: w.frame.minX, width: w.frame.width,
                        topY: w.frame.maxY, maxHeight: 22, cornerRadius: w.cornerRadius)
        piles[w.id] = pile
        addChild(pile.node)
        return pile
    }

    private func groundPile() -> Pile? {
        if let g = piles[groundID] { return g }
        let g = Pile(windowID: groundID, originX: screenFrame.minX, width: screenFrame.width,
                     topY: groundY, maxHeight: 36)
        piles[groundID] = g
        addChild(g.node)
        return g
    }

    /// Drop piles of windows that no longer exist on this screen; remove melted piles.
    private func syncPilesWithWindows() {
        let alive = Set((tracker?.windows ?? []).map(\.id))
        for (id, pile) in piles where id != groundID && (!alive.contains(id) || pile.isEmpty) {
            pile.node.removeFromParent()
            piles.removeValue(forKey: id)
        }
    }

    private func redrawPiles() {
        let windows = tracker?.windows ?? []
        let order = Dictionary(windows.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })

        for pile in piles.values {
            let path = CGMutablePath()
            let ox = pile.originX - screenFrame.minX
            let oy = pile.topY - screenFrame.minY
            let index = order[pile.windowID]
            // Each visible run of snow is drawn along the top of the snow, then back along its
            // base, so the base can follow a rounded corner instead of a straight line.
            var top: [CGPoint] = []
            var base: [CGPoint] = []
            func flush() {
                guard let first = top.first else { return }
                path.move(to: base.first ?? first)
                for p in top { path.addLine(to: p) }
                for p in base.reversed() { path.addLine(to: p) }
                path.closeSubpath()
                top.removeAll()
                base.removeAll()
            }

            for (c, h) in pile.heights.enumerated() {
                let gx = pile.originX + CGFloat(c) * Pile.columnWidth
                // Hide the parts of a pile that sit behind a window in front.
                let hidden = index.map { tracker?.isCovered(CGPoint(x: gx, y: pile.topY + 1), inFrontOf: $0) ?? false } ?? false
                let height = hidden ? 0 : h
                let x = ox + CGFloat(c) * Pile.columnWidth
                let y = oy - pile.baseDrop[c]
                if height > 0.3 {
                    if top.isEmpty { top.append(CGPoint(x: x, y: y)); base.append(CGPoint(x: x, y: y)) }
                    top.append(CGPoint(x: x + Pile.columnWidth / 2, y: y + height))
                    base.append(CGPoint(x: x + Pile.columnWidth / 2, y: y))
                } else if !top.isEmpty {
                    top.append(CGPoint(x: x, y: y))
                    base.append(CGPoint(x: x, y: y))
                    flush()
                }
            }
            if !top.isEmpty {
                let last = pile.heights.count - 1
                let end = CGPoint(x: ox + pile.width, y: oy - pile.baseDrop[last])
                top.append(end)
                base.append(end)
                flush()
            }
            pile.node.path = path
        }
    }

    // MARK: - Textures

    private static func makeFlakeTexture() -> SKTexture {
        let size = 16
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let gradient = NSGradient(colors: [NSColor(white: 1, alpha: 1), NSColor(white: 1, alpha: 0)])
            gradient?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
            return true
        }
        return SKTexture(image: image)
    }

    private static func makeDropTexture() -> SKTexture {
        let image = NSImage(size: NSSize(width: 4, height: 32), flipped: false) { rect in
            let gradient = NSGradient(colors: [NSColor(calibratedRed: 0.8, green: 0.9, blue: 1, alpha: 0),
                                               NSColor(calibratedRed: 0.8, green: 0.9, blue: 1, alpha: 1)])
            gradient?.draw(in: rect, angle: -90)
            return true
        }
        return SKTexture(image: image)
    }
}
