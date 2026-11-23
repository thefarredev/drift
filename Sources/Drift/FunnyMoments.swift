import AppKit
import SpriteKit

/// How often the little scenes happen on their own.
enum MomentFrequency: String, CaseIterable, Identifiable {
    case off, sometimes, often
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Something animated that lives for a while. `step` returns false when it is finished
/// (it has already removed its own nodes by then).
protocol MomentActor: AnyObject {
    func step(_ dt: CGFloat) -> Bool
}

/// Runs the funny moments on one screen: snow workers, the snow plough, snowmen,
/// and the "buried while you're away" drift with the dig-out crew.
final class MomentsDirector {
    unowned let scene: WeatherOverlayScene
    var frequency: MomentFrequency = .sometimes

    private var actors: [MomentActor] = []
    private var snowmen: [CGWindowID: SnowmanActor] = [:]
    private var crewTimer: CGFloat = .random(in: 25...45)
    private var ploughTimer: CGFloat = 10
    private var snowmanTimer: CGFloat = 12

    // Buried while away. Level is 0 (nothing) to 1 (whole screen).
    private(set) var buryLevel: CGFloat = 0
    private var buryRate: CGFloat = 0           // level per second while rising
    private var buryNode: SKShapeNode?
    private var buryRedraw: CGFloat = 0
    private var buryPhase: CGFloat = 0
    private var digOut: DigOutActor?
    private var demoTimer: CGFloat?

    /// Snow falls harder while the screen is being buried.
    var spawnBoost: CGFloat { buryRate > 0 ? 2.2 : 1 }

    init(scene: WeatherOverlayScene) { self.scene = scene }

    // MARK: - Frame loop

    func update(dt: CGFloat) {
        actors = actors.filter { $0.step(dt) }
        snowmen = snowmen.filter { _, s in !s.finished }

        if frequency != .off && scene.weather == .snow && scene.settle && digOut == nil {
            autoCrew(dt)
            autoPlough(dt)
            autoSnowman(dt)
        }
        updateBury(dt)
    }

    // MARK: - Things you can trigger from the menu

    func sendCrew() {
        guard let pile = bestWindowPile(minimum: 6) else { return }
        actors.append(ShovelWorkerActor(scene: scene, pile: pile))
    }

    func sendPlough() {
        guard let ground = scene.ground() else { return }
        actors.append(PloughActor(scene: scene, pile: ground))
    }

    @discardableResult
    func buildSnowman(force: Bool = false) -> Bool {
        var candidates = scene.piles.values.filter { snowmen[$0.windowID] == nil }
        candidates.shuffle()
        for pile in candidates {
            if let x = snowmanSpot(on: pile, force: force) {
                let actor = SnowmanActor(scene: scene, pile: pile, x: x)
                snowmen[pile.windowID] = actor
                actors.append(actor)
                return true
            }
        }
        // Nothing deep enough yet: when forced, use the ground.
        if force, snowmen[scene.groundID] == nil, let ground = scene.ground() {
            let x = scene.screenFrame.minX + scene.screenFrame.width * .random(in: 0.2...0.8)
            // Heap up a little snow where it will stand.
            if let centre = ground.column(forX: x) {
                for c in max(0, centre - 20)...min(ground.heights.count - 1, centre + 20) {
                    let falloff = 1 - CGFloat(abs(c - centre)) / 21
                    ground.heights[c] = max(ground.heights[c], ground.maxHeight * 0.5 * falloff)
                }
            }
            let actor = SnowmanActor(scene: scene, pile: ground, x: x)
            snowmen[scene.groundID] = actor
            actors.append(actor)
            return true
        }
        return false
    }

    /// Start burying the screen. `minutes` = how long until it is fully covered.
    func startBurying(minutes: Double) {
        guard digOut == nil else { return }
        buryRate = CGFloat(1 / (minutes * 60))
    }

    /// You're back: stop burying and send the crew to dig you out.
    func returnFromAway() {
        buryRate = 0
        demoTimer = nil
        guard buryLevel > 0.01, digOut == nil else {
            removeBury()
            return
        }
        let crew = DigOutActor(scene: scene, director: self, startLevel: buryLevel)
        digOut = crew
        actors.append(crew)
    }

    /// Demo for the menu: buried in a few seconds, then dug out.
    func demoBury() {
        guard digOut == nil else { return }
        buryRate = 1.0 / 6        // full-ish in about 5 seconds
        demoTimer = 5.5
    }

    // MARK: - Automatic moments

    private func autoCrew(_ dt: CGFloat) {
        crewTimer -= dt
        guard crewTimer <= 0 else { return }
        crewTimer = frequency == .often ? .random(in: 30...70) : .random(in: 90...180)
        if let pile = bestWindowPile(minimum: 40) {
            actors.append(ShovelWorkerActor(scene: scene, pile: pile))
        }
    }

    private func autoPlough(_ dt: CGFloat) {
        ploughTimer -= dt
        guard ploughTimer <= 0 else { return }
        ploughTimer = 10
        guard let ground = scene.piles[scene.groundID], !actors.contains(where: { $0 is PloughActor }) else { return }
        let average = ground.heights.reduce(0, +) / CGFloat(max(1, ground.heights.count))
        let threshold: CGFloat = frequency == .often ? 7 : 12
        if average > threshold {
            actors.append(PloughActor(scene: scene, pile: ground))
            ploughTimer = 60
        }
    }

    private func autoSnowman(_ dt: CGFloat) {
        snowmanTimer -= dt
        guard snowmanTimer <= 0 else { return }
        snowmanTimer = 10
        let chance: Double = frequency == .often ? 0.5 : 0.2
        guard snowmen.count < 3, Double.random(in: 0...1) < chance else { return }
        buildSnowman()
    }

    /// The window pile with the most visible snow.
    private func bestWindowPile(minimum: CGFloat) -> Pile? {
        var best: (Pile, CGFloat)?
        for pile in scene.piles.values where pile.windowID != scene.groundID && pile.width > 80 {
            var total: CGFloat = 0
            for (c, h) in pile.heights.enumerated() where h > 0 {
                let x = pile.originX + CGFloat(c) * Pile.columnWidth
                if !scene.isCovered(CGPoint(x: x, y: pile.topY + 1), on: pile) { total += h }
            }
            if total >= minimum, total > (best?.1 ?? 0) { best = (pile, total) }
        }
        return best?.0
    }

    /// Centre x of a deep, visible stretch of snow (at least ~30pt wide).
    private func snowmanSpot(on pile: Pile, force: Bool) -> CGFloat? {
        let need = force ? pile.maxHeight * 0.35 : pile.maxHeight * 0.7
        let run = 10
        var start: Int?
        for c in pile.heights.indices {
            let x = pile.originX + CGFloat(c) * Pile.columnWidth
            let ok = pile.heights[c] >= need && !scene.isCovered(CGPoint(x: x, y: pile.topY + 1), on: pile)
            if ok {
                if start == nil { start = c }
                if let s = start, c - s + 1 >= run {
                    return pile.originX + CGFloat(s + run / 2) * Pile.columnWidth
                }
            } else {
                start = nil
            }
        }
        return nil
    }

    // MARK: - Buried while away

    /// Global y of the top of the drift at x, or nil when nothing is buried.
    func buryTopY(atGlobalX x: CGFloat) -> CGFloat? {
        guard buryLevel > 0.005 else { return nil }
        let lx = x - scene.screenFrame.minX
        return scene.screenFrame.minY + waveY(lx)
    }

    /// Local y of the drift's wavy top edge.
    private func waveY(_ lx: CGFloat) -> CGFloat {
        let h = scene.screenFrame.height * 1.06
        return buryLevel * h + sin(lx / 90 + buryPhase) * 9 * buryLevel.squareRoot()
            + sin(lx / 33 + buryPhase * 1.7) * 3
    }

    fileprivate func setBuryLevel(_ level: CGFloat) {
        buryLevel = max(0, min(1, level))
    }

    fileprivate func finishDigOut() {
        digOut = nil
        removeBury()
    }

    private func removeBury() {
        buryLevel = 0
        buryNode?.removeFromParent()
        buryNode = nil
    }

    private func updateBury(_ dt: CGFloat) {
        if buryRate > 0 { setBuryLevel(buryLevel + buryRate * dt) }
        if let t = demoTimer {
            demoTimer = t - dt
            if t - dt <= 0 { returnFromAway() }
        }
        guard buryLevel > 0.005 else {
            buryNode?.removeFromParent()
            buryNode = nil
            return
        }
        if buryNode == nil {
            let node = SKShapeNode()
            node.fillColor = NSColor(calibratedWhite: 0.985, alpha: 1)
            node.strokeColor = NSColor(calibratedRed: 0.8, green: 0.87, blue: 0.96, alpha: 1)
            node.lineWidth = 1.5
            node.zPosition = 1.5          // above window piles, below falling flakes and workers
            scene.addChild(node)
            buryNode = node
        }
        buryPhase += dt * 0.25
        buryRedraw += dt
        guard buryRedraw > 0.08 else { return }
        buryRedraw = 0
        let w = scene.screenFrame.width
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -10, y: -10))
        var x: CGFloat = -10
        while x <= w + 10 {
            path.addLine(to: CGPoint(x: x, y: waveY(x)))
            x += 8
        }
        path.addLine(to: CGPoint(x: w + 10, y: -10))
        path.closeSubpath()
        buryNode?.path = path
    }
}

// MARK: - Actors

/// A worker walks along a window's snow pile, shovelling it off the edge.
private final class ShovelWorkerActor: MomentActor {
    let node = WorkerNode()
    weak var pile: Pile?
    unowned let scene: WeatherOverlayScene
    var x: CGFloat
    let endX: CGFloat
    let dir: CGFloat
    var carried: CGFloat = 0
    var throwTimer: CGFloat = 0
    var falling = false
    var vy: CGFloat = 0

    init(scene: WeatherOverlayScene, pile: Pile) {
        self.scene = scene
        self.pile = pile
        dir = Bool.random() ? 1 : -1
        let left = pile.originX + 6, right = pile.originX + pile.width - 6
        x = dir > 0 ? left : right
        endX = dir > 0 ? right : left
        node.zPosition = 5
        node.xScale = dir
        node.alpha = 0
        node.position = scene.local(CGPoint(x: x, y: pile.topY))
        scene.addChild(node)
        node.run(.fadeIn(withDuration: 0.4))
    }

    func step(_ dt: CGFloat) -> Bool {
        guard !falling, let pile, scene.piles[pile.windowID] === pile else { return fall(dt) }

        x += dir * 24 * dt
        // Clear the snow just in front of the shovel.
        var gx = x
        while (dir > 0 && gx <= x + 6) || (dir < 0 && gx >= x - 6) {
            if let c = pile.column(forX: gx) {
                carried += pile.heights[c]
                pile.heights[c] = 0
            }
            gx += dir * Pile.columnWidth
        }
        // Toss it over the shoulder, off the window.
        throwTimer += dt
        if throwTimer > 0.35, carried > 0.5 {
            let clumps = min(4, Int(carried / 4) + 1)
            for _ in 0..<clumps {
                scene.spawn(at: CGPoint(x: x - dir * 3, y: pile.topY + 12),
                            velocity: CGVector(dx: -dir * .random(in: 40...90), dy: .random(in: 70...130)),
                            rain: false, size: .random(in: 2...3.6), settles: false)
            }
            carried = 0
            throwTimer = 0
        }

        node.animate(dt: dt, walking: true, digging: true)
        node.position = scene.local(CGPoint(x: x, y: pile.topY))
        node.isHidden = scene.isCovered(CGPoint(x: x, y: pile.topY + 1), on: pile)

        if (dir > 0 && x >= endX) || (dir < 0 && x <= endX) {
            node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
            return false
        }
        return true
    }

    /// The window moved under the worker: they tumble down and vanish.
    private func fall(_ dt: CGFloat) -> Bool {
        falling = true
        vy -= 500 * dt
        node.position.y += vy * dt
        node.zRotation += dt * 6
        node.alpha -= dt * 1.2
        if node.alpha <= 0 || node.position.y < -30 {
            node.removeFromParent()
            return false
        }
        return true
    }
}

/// A snow plough drives along the Dock (or the screen bottom), clearing the snow.
private final class PloughActor: MomentActor {
    let node = PloughNode()
    weak var pile: Pile?
    unowned let scene: WeatherOverlayScene
    var x: CGFloat
    let endX: CGFloat
    let dir: CGFloat
    let speed: CGFloat = 75
    var sprayTimer: CGFloat = 0

    init(scene: WeatherOverlayScene, pile: Pile) {
        self.scene = scene
        self.pile = pile
        dir = Bool.random() ? 1 : -1
        let f = scene.screenFrame
        x = dir > 0 ? f.minX - 40 : f.maxX + 40
        endX = dir > 0 ? f.maxX + 40 : f.minX - 40
        node.zPosition = 5
        node.xScale = dir
        node.position = scene.local(CGPoint(x: x, y: pile.topY))
        scene.addChild(node)
    }

    func step(_ dt: CGFloat) -> Bool {
        guard let pile, scene.piles[pile.windowID] === pile else {
            node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            return false
        }
        x += dir * speed * dt
        let bladeX = x + dir * 15
        var moved: CGFloat = 0
        for offset in stride(from: CGFloat(0), through: 6, by: Pile.columnWidth) {
            if let c = pile.column(forX: bladeX + dir * offset) {
                moved += pile.heights[c]
                pile.heights[c] = min(pile.heights[c], 1.5)
            }
        }
        sprayTimer += dt
        if sprayTimer > 0.06, moved > 1 {
            sprayTimer = 0
            for _ in 0..<min(5, Int(moved / 5) + 1) {
                scene.spawn(at: CGPoint(x: bladeX, y: pile.topY + 8),
                            velocity: CGVector(dx: dir * .random(in: 30...110), dy: .random(in: 90...170)),
                            rain: false, size: .random(in: 1.8...3.2), settles: false)
            }
        }
        node.animate(dt: dt, speed: speed)
        node.position = scene.local(CGPoint(x: x, y: pile.topY))
        if (dir > 0 && x >= endX) || (dir < 0 && x <= endX) {
            node.removeFromParent()
            return false
        }
        return true
    }
}

/// A snowman that builds itself on a deep pile, and melts or tumbles when the snow goes.
final class SnowmanActor: MomentActor {
    let node: SnowmanNode
    weak var pile: Pile?
    unowned let scene: WeatherOverlayScene
    let x: CGFloat
    let columns: [Int]
    private(set) var finished = false
    private var falling = false
    private var vy: CGFloat = 0

    init(scene: WeatherOverlayScene, pile: Pile, x: CGFloat) {
        self.scene = scene
        self.pile = pile
        self.x = x
        let height = pile.maxHeight * 1.35
        node = SnowmanNode(height: height)
        // The snow under the snowman gets used up to build it.
        let half = Int(height * 0.3 / Pile.columnWidth)
        let centre = pile.column(forX: x) ?? 0
        columns = Array(max(0, centre - half)...min(pile.heights.count - 1, centre + half))
        let base = columns.map { pile.heights[$0] }.min() ?? 0
        for c in columns { pile.heights[c] = max(base * 0.6, 1) }
        node.zPosition = 4
        node.position = scene.local(CGPoint(x: x, y: pile.topY + base * 0.6 - 1))
        scene.addChild(node)
    }

    func step(_ dt: CGFloat) -> Bool {
        guard !falling, let pile, scene.piles[pile.windowID] === pile else { return tumble(dt) }
        node.isHidden = scene.isCovered(CGPoint(x: x, y: pile.topY + 1), on: pile)
        // Melt away when the snow around it has melted or been cleared.
        let around = columns.map { pile.heights[$0] }.reduce(0, +) / CGFloat(max(1, columns.count))
        if around < 0.4 {
            node.yScale -= dt * 0.25
            node.alpha -= dt * 0.25
            if node.alpha <= 0.05 { return done() }
        }
        return true
    }

    private func tumble(_ dt: CGFloat) -> Bool {
        falling = true
        vy -= 500 * dt
        node.position.y += vy * dt
        node.zRotation -= dt * 3
        node.alpha -= dt
        if node.alpha <= 0 || node.position.y < -60 { return done() }
        return true
    }

    private func done() -> Bool {
        node.removeFromParent()
        finished = true
        return false
    }
}

/// When you come back: a crew stands on the drift, shovelling, while it sinks away.
private final class DigOutActor: MomentActor {
    unowned let scene: WeatherOverlayScene
    unowned let director: MomentsDirector
    let startLevel: CGFloat
    let duration: CGFloat = 5
    var elapsed: CGFloat = 0
    var workers: [(node: WorkerNode, x: CGFloat)] = []
    let plough = PloughNode()
    var ploughX: CGFloat
    var throwTimer: CGFloat = 0

    init(scene: WeatherOverlayScene, director: MomentsDirector, startLevel: CGFloat) {
        self.scene = scene
        self.director = director
        self.startLevel = startLevel
        let f = scene.screenFrame
        for fraction in [0.22, 0.5, 0.78] as [CGFloat] {
            let worker = WorkerNode()
            worker.zPosition = 5
            worker.setScale(1.6)
            worker.xScale = Bool.random() ? 1.6 : -1.6
            worker.alpha = 0
            worker.run(.fadeIn(withDuration: 0.3))
            scene.addChild(worker)
            workers.append((worker, f.minX + f.width * fraction))
        }
        ploughX = f.minX - 60
        plough.setScale(1.6)
        plough.zPosition = 5
        scene.addChild(plough)
    }

    func step(_ dt: CGFloat) -> Bool {
        elapsed += dt
        let progress = min(1, elapsed / duration)
        // Ease out: fast at first, gentle at the end.
        director.setBuryLevel(startLevel * pow(1 - progress, 1.6))

        throwTimer += dt
        let shouldThrow = throwTimer > 0.12
        if shouldThrow { throwTimer = 0 }

        for (worker, x) in workers {
            let top = director.buryTopY(atGlobalX: x) ?? scene.screenFrame.minY
            worker.position = scene.local(CGPoint(x: x, y: top))
            worker.animate(dt: dt, walking: false, digging: true)
            if shouldThrow && progress < 0.95 {
                scene.spawn(at: CGPoint(x: x, y: top + 22),
                            velocity: CGVector(dx: .random(in: -110...110), dy: .random(in: 120...220)),
                            rain: false, size: .random(in: 2.5...4.5), settles: false)
            }
        }

        ploughX += 220 * dt
        let ploughTop = director.buryTopY(atGlobalX: ploughX) ?? scene.screenFrame.minY
        plough.position = scene.local(CGPoint(x: ploughX, y: ploughTop))
        plough.animate(dt: dt, speed: 220)

        if progress >= 1 {
            for (worker, _) in workers { worker.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()])) }
            plough.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
            director.finishDigOut()
            return false
        }
        return true
    }
}
