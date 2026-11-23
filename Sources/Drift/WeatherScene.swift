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

    init(windowID: CGWindowID, originX: CGFloat, width: CGFloat, topY: CGFloat, maxHeight: CGFloat) {
        self.windowID = windowID
        self.originX = originX
        self.topY = topY
        self.maxHeight = maxHeight
        self.heights = Array(repeating: 0, count: max(1, Int(width / Pile.columnWidth)))
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

    func surfaceY(atColumn c: Int) -> CGFloat { topY + heights[c] }

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
        heights[c] = min(maxHeight, heights[c] + amount)
        // Edges of a window stay thin so the pile looks rounded, like real snow on a ledge.
        let edgeFalloff: CGFloat = 4
        for i in 0..<min(Int(edgeFalloff), heights.count) {
            let cap = maxHeight * CGFloat(i + 1) / (edgeFalloff + 1)
            heights[i] = min(heights[i], cap)
            heights[heights.count - 1 - i] = min(heights[heights.count - 1 - i], cap)
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

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20))
        lastTime = currentTime
        elapsed += dt

        updateFullScreenState()
        spawnNew(dt: dt)
        step(dt: dt)
        melt(dt: dt)
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
        spawnAccumulator += spawnRate * Double(moments.spawnBoost) * Double(screenFrame.width / 1000) * Double(dt)
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
        // 0) The "buried while you're away" drift swallows everything that reaches it.
        if let buryTop = moments.buryTopY(atGlobalX: p.pos.x), p.pos.y <= buryTop, p.vel.dy <= 0 { return true }
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
                        topY: w.frame.maxY, maxHeight: 22)
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
            var drawing = false

            for (c, h) in pile.heights.enumerated() {
                let gx = pile.originX + CGFloat(c) * Pile.columnWidth
                // Hide the parts of a pile that sit behind a window in front.
                let hidden = index.map { tracker?.isCovered(CGPoint(x: gx, y: pile.topY + 1), inFrontOf: $0) ?? false } ?? false
                let height = hidden ? 0 : h
                let x = ox + CGFloat(c) * Pile.columnWidth
                if height > 0.3 {
                    if !drawing { path.move(to: CGPoint(x: x, y: oy)); drawing = true }
                    path.addLine(to: CGPoint(x: x, y: oy + height))
                } else if drawing {
                    path.addLine(to: CGPoint(x: x, y: oy))
                    path.closeSubpath()
                    drawing = false
                }
            }
            if drawing {
                path.addLine(to: CGPoint(x: ox + pile.width, y: oy))
                path.closeSubpath()
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
