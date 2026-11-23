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

/// Runs the funny moments on one screen: snow workers, the snow plough, snowmen that
/// grow by themselves, and the "buried while you're away" drifts with the dig-out crew.
final class MomentsDirector {
    unowned let scene: WeatherOverlayScene
    var frequency: MomentFrequency = .sometimes

    private var actors: [MomentActor] = []
    private var snowmen: [CGWindowID: SnowmanActor] = [:]
    private var crewTimer: CGFloat = .random(in: 25...45)
    private var ploughTimer: CGFloat = 10
    private var snowmanTimer: CGFloat = 20

    // Buried while away: the ground pile is allowed to grow up the whole screen.
    private(set) var burying = false
    private var buryRate: CGFloat = 0            // pt per second of drift growth
    private var buryNoise: [CGFloat] = []
    private var buryNoiseTimer: CGFloat = 0
    private var smoothTimer: CGFloat = 0
    private var digOut: DigOutActor?
    private var demoTimer: CGFloat?
    static let normalGroundMax: CGFloat = 36
    static let normalWindowMax: CGFloat = 22

    /// Snow falls harder while the screen is being buried.
    var spawnBoost: CGFloat { burying ? 2.5 : 1 }

    init(scene: WeatherOverlayScene) { self.scene = scene }

    // MARK: - Frame loop

    func update(dt: CGFloat) {
        actors = actors.filter { $0.step(dt) }
        snowmen = snowmen.filter { _, s in !s.finished }

        if frequency != .off && scene.weather == .snow && scene.settle && digOut == nil && !burying {
            autoCrew(dt)
            autoPlough(dt)
            autoSnowman(dt)
        }
        updateBury(dt)
        if let t = demoTimer {
            demoTimer = t - dt
            if t - dt <= 0 { returnFromAway() }
        }
        // The pointer can knock snowmen over.
        if scene.cursorSpeed > 20 {
            for s in snowmen.values { s.cursorPassed(scene.cursor, velocity: scene.cursorVel) }
        }
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

    /// From the menu: start a snowman right away and let it grow in about 15 seconds.
    @discardableResult
    func buildSnowman() -> Bool {
        if startSnowman(minimumFraction: 0.3, seconds: 15) { return true }
        // Not enough snow anywhere: heap a little up on the ground first.
        guard snowmen[scene.groundID] == nil, let ground = scene.ground() else { return false }
        let x = scene.screenFrame.minX + scene.screenFrame.width * .random(in: 0.2...0.8)
        if let centre = ground.column(forX: x) {
            for c in max(0, centre - 20)...min(ground.heights.count - 1, centre + 20) {
                let falloff = 1 - CGFloat(abs(c - centre)) / 21
                ground.heights[c] = max(ground.heights[c], ground.maxHeight * 0.5 * falloff)
            }
        }
        let actor = SnowmanActor(scene: scene, pile: ground, x: x, seconds: 15)
        snowmen[scene.groundID] = actor
        actors.append(actor)
        return true
    }

    /// Start burying the screen. `minutes` = roughly how long until it is fully covered.
    func startBurying(minutes: Double) {
        guard digOut == nil, !burying, let ground = scene.ground() else { return }
        burying = true
        buryRate = scene.screenFrame.height / CGFloat(minutes * 60)
        ground.maxHeight = scene.screenFrame.height * 1.05
        for pile in scene.piles.values where pile !== ground { pile.maxHeight = 60 }
        buryNoise = smoothNoise(count: ground.heights.count)
    }

    /// You're back: stop burying and send the crew to dig you out.
    func returnFromAway() {
        demoTimer = nil
        guard burying else { return }
        burying = false
        guard digOut == nil, let ground = scene.piles[scene.groundID] else { restoreLimits(); return }
        let crew = DigOutActor(scene: scene, director: self, ground: ground)
        digOut = crew
        actors.append(crew)
    }

    /// Demo for the menu: drifts pile up for about 8 seconds, then the crew digs you out.
    func demoBury() {
        guard digOut == nil, !burying else { return }
        startBurying(minutes: 0.15)
        demoTimer = 8
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

    /// Now and then a snowman starts forming in deep snow. It grows over a couple of
    /// minutes, and only keeps growing while nobody clears that spot.
    private func autoSnowman(_ dt: CGFloat) {
        snowmanTimer -= dt
        guard snowmanTimer <= 0 else { return }
        snowmanTimer = 15
        let chance: Double = frequency == .often ? 0.35 : 0.15
        guard snowmen.count < 3, Double.random(in: 0...1) < chance else { return }
        startSnowman(minimumFraction: 0.7, seconds: frequency == .often ? 90 : 150)
    }

    @discardableResult
    private func startSnowman(minimumFraction: CGFloat, seconds: CGFloat) -> Bool {
        var candidates = scene.piles.values.filter { snowmen[$0.windowID] == nil }
        candidates.shuffle()
        for pile in candidates {
            if let x = snowmanSpot(on: pile, fraction: minimumFraction) {
                let actor = SnowmanActor(scene: scene, pile: pile, x: x, seconds: seconds)
                snowmen[pile.windowID] = actor
                actors.append(actor)
                return true
            }
        }
        return false
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
    private func snowmanSpot(on pile: Pile, fraction: CGFloat) -> CGFloat? {
        let need = min(pile.maxHeight, MomentsDirector.normalGroundMax) * fraction
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

    private func updateBury(_ dt: CGFloat) {
        guard burying, let ground = scene.piles[scene.groundID] else { return }
        if buryNoise.count != ground.heights.count { buryNoise = smoothNoise(count: ground.heights.count) }

        // Drifts grow unevenly: some spots faster than others, and the pattern slowly shifts,
        // so it looks like wind-blown snow building up rather than a flat wall.
        buryNoiseTimer += dt
        if buryNoiseTimer > 6 {
            buryNoiseTimer = 0
            let fresh = smoothNoise(count: ground.heights.count)
            for i in buryNoise.indices { buryNoise[i] = buryNoise[i] * 0.6 + fresh[i] * 0.4 }
        }
        for c in ground.heights.indices {
            ground.heights[c] = min(ground.maxHeight, ground.heights[c] + buryRate * dt * buryNoise[c])
        }
        // Let steep bits slump a little so the surface stays soft and rounded.
        smoothTimer += dt
        if smoothTimer > 0.15 {
            smoothTimer = 0
            relax(ground, strength: 0.25)
        }
        // Windows get deeper snow too.
        for pile in scene.piles.values where pile !== ground {
            for c in pile.heights.indices { pile.heights[c] = min(pile.maxHeight, pile.heights[c] + dt * 1.5 * buryNoise[c % max(1, buryNoise.count)]) }
        }
    }

    fileprivate func finishDigOut() {
        digOut = nil
        restoreLimits()
    }

    private func restoreLimits() {
        for pile in scene.piles.values {
            let limit = pile.windowID == scene.groundID ? MomentsDirector.normalGroundMax : MomentsDirector.normalWindowMax
            pile.maxHeight = limit
            for c in pile.heights.indices { pile.heights[c] = min(pile.heights[c], limit) }
        }
    }

    /// Smooth random values around 1 (between ~0.3 and ~1.7), one per column.
    private func smoothNoise(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        // A few random control points, eased between: gentle hills a few hundred points wide.
        let step = 40
        let points = (0...(count / step + 1)).map { _ in CGFloat.random(in: 0.3...1.7) }
        return (0..<count).map { i in
            let a = points[i / step], b = points[i / step + 1]
            let t = CGFloat(i % step) / CGFloat(step)
            let eased = t * t * (3 - 2 * t)
            return a + (b - a) * eased
        }
    }
}

/// Blend each column a little toward its neighbours (soft, rounded snow).
private func relax(_ pile: Pile, strength: CGFloat) {
    let h = pile.heights
    guard h.count > 2 else { return }
    for c in 1..<(h.count - 1) {
        let avg = (h[c - 1] + h[c + 1]) / 2
        pile.heights[c] = h[c] + (avg - h[c]) * strength
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

/// A snowman that slowly grows on a deep pile while nobody clears that spot.
/// It falls apart into clumps if a worker or the plough clears under it, if the window
/// moves, or if you swipe the pointer through it.
final class SnowmanActor: MomentActor {
    let node: SnowmanNode
    weak var pile: Pile?
    unowned let scene: WeatherOverlayScene
    let x: CGFloat
    let columns: [Int]
    private let growRate: CGFloat
    private var progress: CGFloat = 0
    private let startDepth: CGFloat
    private var wobble: CGFloat = 0
    private var wobblePhase: CGFloat = 0
    private(set) var finished = false

    init(scene: WeatherOverlayScene, pile: Pile, x: CGFloat, seconds: CGFloat) {
        self.scene = scene
        self.pile = pile
        self.x = x
        growRate = 1 / max(1, seconds)
        let height = min(pile.maxHeight, MomentsDirector.normalGroundMax) * 1.35
        node = SnowmanNode(height: height)
        let half = Int(height * 0.3 / Pile.columnWidth)
        let centre = pile.column(forX: x) ?? 0
        columns = Array(max(0, centre - half)...min(pile.heights.count - 1, centre + half))
        startDepth = max(1, columns.map { pile.heights[$0] }.reduce(0, +) / CGFloat(max(1, columns.count)))
        node.zPosition = 4
        scene.addChild(node)
        place()
    }

    func step(_ dt: CGFloat) -> Bool {
        guard !finished else { return false }
        guard let pile, scene.piles[pile.windowID] === pile else { return breakApart(push: .zero) }

        let depth = columns.map { pile.heights[$0] }.reduce(0, +) / CGFloat(max(1, columns.count))
        // Someone cleared the snow under it: it collapses.
        if depth < startDepth * 0.35 { return breakApart(push: .zero) }

        // Grows only while it's snowing; slowly melts back otherwise.
        if scene.weather == .snow {
            progress = min(1, progress + growRate * dt)
        } else {
            progress = max(0, progress - dt / 240)
            if progress <= 0 { return breakApart(push: .zero) }
        }
        node.setProgress(progress)

        // A gentle wobble after the pointer brushed past.
        wobble *= max(0, 1 - dt * 3)
        wobblePhase += dt * 9
        node.zRotation = sin(wobblePhase) * wobble

        place()
        node.isHidden = scene.isCovered(CGPoint(x: x, y: pile.topY + 1), on: pile)
        return true
    }

    /// Called while the pointer moves. A slow brush makes it wobble; a swipe knocks it over.
    func cursorPassed(_ p: CGPoint, velocity: CGVector) {
        guard !finished, !node.isHidden, progress > 0.05 else { return }
        let base = node.position
        let local = CGPoint(x: p.x - scene.screenFrame.minX, y: p.y - scene.screenFrame.minY)
        let h = node.height * min(1, progress * 1.2)
        guard abs(local.x - base.x) < node.height * 0.3, local.y > base.y - 2, local.y < base.y + h else { return }
        let speed = hypot(velocity.dx, velocity.dy)
        if speed > 260 {
            _ = breakApart(push: velocity)
        } else {
            wobble = min(0.25, wobble + speed / 2000)
        }
    }

    private func place() {
        guard let pile else { return }
        let floor = columns.map { pile.heights[$0] }.min() ?? 0
        node.position = scene.local(CGPoint(x: x, y: pile.topY + floor * 0.75 - 1))
    }

    /// Bursts into snow clumps that fall and settle again.
    private func breakApart(push: CGVector) -> Bool {
        guard !finished else { return false }
        finished = true
        let origin = CGPoint(x: x, y: node.position.y + scene.screenFrame.minY)
        for (centre, radius) in node.ballCentres {
            let count = max(2, Int(radius * 1.2))
            for _ in 0..<count {
                let p = CGPoint(x: origin.x + centre.x + .random(in: -radius...radius),
                                y: origin.y + centre.y + .random(in: -radius...radius))
                scene.spawn(at: p,
                            velocity: CGVector(dx: push.dx * 0.15 + .random(in: -40...40),
                                               dy: push.dy * 0.1 + .random(in: 10...90)),
                            rain: false, size: .random(in: 2.2...4.2))
            }
        }
        node.run(.sequence([.group([.fadeOut(withDuration: 0.15), .scale(to: 1.15, duration: 0.15)]), .removeFromParent()]))
        return false
    }
}

/// When you come back: a crew digs trenches into the drifts while a plough helps,
/// until the snow is back down to a normal layer above the Dock.
private final class DigOutActor: MomentActor {
    unowned let scene: WeatherOverlayScene
    unowned let director: MomentsDirector
    weak var ground: Pile?
    let duration: CGFloat = 7
    var elapsed: CGFloat = 0
    var workers: [(node: WorkerNode, x: CGFloat, dir: CGFloat)] = []
    let plough = PloughNode()
    var ploughX: CGFloat
    var throwTimer: CGFloat = 0
    let startMax: CGFloat
    let rest: CGFloat = 8

    init(scene: WeatherOverlayScene, director: MomentsDirector, ground: Pile) {
        self.scene = scene
        self.director = director
        self.ground = ground
        startMax = max(rest + 1, ground.heights.max() ?? rest)
        let f = scene.screenFrame
        let count = 4
        for i in 0..<count {
            let worker = WorkerNode()
            worker.zPosition = 5
            let dir: CGFloat = Bool.random() ? 1 : -1
            worker.setScale(1.5)
            worker.xScale = 1.5 * dir
            worker.alpha = 0
            worker.run(.fadeIn(withDuration: 0.3))
            scene.addChild(worker)
            let x = f.minX + f.width * (CGFloat(i) + 0.5) / CGFloat(count) + .random(in: -60...60)
            workers.append((worker, x, dir))
        }
        ploughX = f.minX - 60
        plough.setScale(1.5)
        plough.zPosition = 5
        scene.addChild(plough)
    }

    func step(_ dt: CGFloat) -> Bool {
        guard let ground else { return finish() }
        elapsed += dt

        // Every column sinks toward the resting layer; near a worker it sinks much faster,
        // so trenches open around the crew and widen until everything is clear.
        let base = (startMax - rest) / duration
        for c in ground.heights.indices where ground.heights[c] > rest {
            let x = ground.originX + CGFloat(c) * Pile.columnWidth
            var near: CGFloat = 0
            for w in workers { near = max(near, exp(-abs(w.x - x) / 70)) }
            let rate = base * (0.6 + near * 3)
            ground.heights[c] = max(rest, ground.heights[c] - rate * dt)
        }
        relax(ground, strength: 0.15)

        throwTimer += dt
        let shouldThrow = throwTimer > 0.15
        if shouldThrow { throwTimer = 0 }
        for i in workers.indices {
            // Walk slowly outwards as they dig.
            workers[i].x += workers[i].dir * 14 * dt
            let (node, x, dir) = workers[i]
            let c = ground.column(forX: x)
            let top = ground.topY + (c.map { ground.heights[$0] } ?? 0)
            node.position = scene.local(CGPoint(x: x, y: top))
            node.animate(dt: dt, walking: true, digging: true)
            if shouldThrow, (c.map { ground.heights[$0] } ?? 0) > rest + 2 {
                scene.spawn(at: CGPoint(x: x - dir * 4, y: top + 20),
                            velocity: CGVector(dx: -dir * .random(in: 50...120), dy: .random(in: 110...200)),
                            rain: false, size: .random(in: 2.5...4.5), settles: false)
            }
        }

        // The plough follows along the resting layer once the drifts are mostly gone.
        if elapsed > duration * 0.45 {
            ploughX += 200 * dt
            let c = ground.column(forX: ploughX)
            plough.position = scene.local(CGPoint(x: ploughX, y: ground.topY + (c.map { ground.heights[$0] } ?? rest)))
            plough.animate(dt: dt, speed: 200)
        }

        let done = !ground.heights.contains { $0 > rest + 0.5 }
        if done && elapsed > 2 { return finish() }
        if elapsed > duration * 2 { return finish() }
        return true
    }

    private func finish() -> Bool {
        for w in workers { w.node.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()])) }
        plough.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        director.finishDigOut()
        return false
    }
}
