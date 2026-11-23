import AppKit
import SpriteKit

// Little characters drawn entirely in code, so the art is ours and easy to animate.
// Every node's origin is at its feet / wheels, facing right (+x). Flip with xScale = -1.

private func shape(_ node: SKShapeNode, _ fill: NSColor, at p: CGPoint = .zero, z: CGFloat = 0) -> SKShapeNode {
    node.fillColor = fill
    node.strokeColor = .clear
    node.lineWidth = 0
    node.position = p
    node.zPosition = z
    return node
}

private enum Palette {
    static let jacket = NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.12, alpha: 1)
    static let stripe = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.55, alpha: 1)
    static let trousers = NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.32, alpha: 1)
    static let skin = NSColor(calibratedRed: 0.97, green: 0.8, blue: 0.66, alpha: 1)
    static let beanie = NSColor(calibratedRed: 0.86, green: 0.17, blue: 0.2, alpha: 1)
    static let wood = NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.2, alpha: 1)
    static let steel = NSColor(calibratedRed: 0.72, green: 0.75, blue: 0.8, alpha: 1)
    static let truck = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.1, alpha: 1)
    static let glass = NSColor(calibratedRed: 0.7, green: 0.88, blue: 1.0, alpha: 1)
    static let tyre = NSColor(calibratedWhite: 0.15, alpha: 1)
    static let snow = NSColor(calibratedWhite: 0.99, alpha: 1)
    static let snowEdge = NSColor(calibratedRed: 0.78, green: 0.86, blue: 0.95, alpha: 1)
}

/// A snow worker in a high-vis jacket and red beanie, with a shovel. About 19pt tall.
final class WorkerNode: SKNode {
    private let leftLeg = shape(SKShapeNode(rectOf: CGSize(width: 2.2, height: 5), cornerRadius: 1), Palette.trousers)
    private let rightLeg = shape(SKShapeNode(rectOf: CGSize(width: 2.2, height: 5), cornerRadius: 1), Palette.trousers)
    private let torso = SKNode()
    private let arm = SKNode()
    private var t = CGFloat.random(in: 0...10)

    override init() {
        super.init()
        leftLeg.position = CGPoint(x: -1.4, y: 2.5)
        rightLeg.position = CGPoint(x: 1.4, y: 2.5)
        addChild(leftLeg)
        addChild(rightLeg)

        torso.position = CGPoint(x: 0, y: 5)
        torso.addChild(shape(SKShapeNode(rectOf: CGSize(width: 7, height: 7.5), cornerRadius: 2), Palette.jacket, at: CGPoint(x: 0, y: 3.6)))
        torso.addChild(shape(SKShapeNode(rectOf: CGSize(width: 7, height: 1.1)), Palette.stripe, at: CGPoint(x: 0, y: 2.6), z: 0.1))
        torso.addChild(shape(SKShapeNode(circleOfRadius: 2.7), Palette.skin, at: CGPoint(x: 0.3, y: 9.6)))
        torso.addChild(shape(SKShapeNode(circleOfRadius: 0.45), .black, at: CGPoint(x: 1.6, y: 9.9), z: 0.1))
        torso.addChild(shape(SKShapeNode(rectOf: CGSize(width: 6, height: 2.4), cornerRadius: 1.1), Palette.beanie, at: CGPoint(x: 0.2, y: 11.7), z: 0.2))
        torso.addChild(shape(SKShapeNode(circleOfRadius: 1.1), Palette.snow, at: CGPoint(x: 0.2, y: 13.3), z: 0.2))
        addChild(torso)

        // Shovel held at the shoulder; rotating `arm` makes the digging motion.
        arm.position = CGPoint(x: 2.2, y: 11)
        let shaft = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 7, y: -7))
        shaft.path = path
        shaft.strokeColor = Palette.wood
        shaft.lineWidth = 1.2
        shaft.lineCap = .round
        arm.addChild(shaft)
        arm.addChild(shape(SKShapeNode(rectOf: CGSize(width: 4, height: 2.6), cornerRadius: 0.6), Palette.steel, at: CGPoint(x: 7.8, y: -7.6)))
        arm.zPosition = 0.5
        addChild(arm)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func animate(dt: CGFloat, walking: Bool, digging: Bool) {
        t += dt
        if walking {
            leftLeg.position.y = 2.5 + max(0, sin(t * 13)) * 1.3
            rightLeg.position.y = 2.5 + max(0, -sin(t * 13)) * 1.3
            torso.position.y = 5 + abs(sin(t * 13)) * 0.5
        } else {
            leftLeg.position.y = 2.5
            rightLeg.position.y = 2.5
        }
        arm.zRotation = digging ? 0.15 + sin(t * 8) * 0.55 : 0.1
    }
}

/// A small snow plough truck with a blade and a blinking amber light. About 34pt long.
final class PloughNode: SKNode {
    private var wheels: [SKNode] = []

    override init() {
        super.init()
        addChild(shape(SKShapeNode(rectOf: CGSize(width: 24, height: 8), cornerRadius: 2), Palette.truck, at: CGPoint(x: -2, y: 7)))
        addChild(shape(SKShapeNode(rectOf: CGSize(width: 10, height: 9), cornerRadius: 2), Palette.truck, at: CGPoint(x: 5, y: 14.5)))
        addChild(shape(SKShapeNode(rectOf: CGSize(width: 6, height: 5), cornerRadius: 1), Palette.glass, at: CGPoint(x: 6.5, y: 15), z: 0.1))
        addChild(shape(SKShapeNode(rectOf: CGSize(width: 24, height: 1.2)), Palette.tyre, at: CGPoint(x: -2, y: 4.8), z: 0.1))

        // Blade in front.
        let blade = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 11, y: 0.5))
        p.addLine(to: CGPoint(x: 16, y: 0))
        p.addLine(to: CGPoint(x: 15, y: 11))
        p.addLine(to: CGPoint(x: 11, y: 9))
        p.closeSubpath()
        blade.path = p
        addChild(shape(blade, Palette.steel, z: 0.2))

        for x in [CGFloat(-9), 5] {
            let wheel = SKNode()
            wheel.position = CGPoint(x: x, y: 3)
            wheel.addChild(shape(SKShapeNode(circleOfRadius: 3), Palette.tyre))
            wheel.addChild(shape(SKShapeNode(rectOf: CGSize(width: 1, height: 4.4)), Palette.steel, z: 0.1))
            wheel.zPosition = 0.3
            addChild(wheel)
            wheels.append(wheel)
        }

        let light = shape(SKShapeNode(circleOfRadius: 1.5), NSColor.orange, at: CGPoint(x: 5, y: 20), z: 0.2)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)])))
        addChild(light)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func animate(dt: CGFloat, speed: CGFloat) {
        for wheel in wheels { wheel.zRotation -= speed * dt / 3 }
    }
}

/// A snowman whose parts appear as `progress` goes from 0 to 1: bottom ball, middle,
/// head, then hat, nose and scarf. The owner decides how fast it grows.
final class SnowmanNode: SKNode {
    let height: CGFloat
    private let bottom: SKShapeNode
    private let middle: SKShapeNode
    private let head = SKNode()
    private let hat = SKNode()
    private let extras: [SKNode]
    private let hatRest: CGFloat

    init(height h: CGFloat) {
        height = h
        let rb = h * 0.24, rm = h * 0.17, rh = h * 0.13
        bottom = SnowmanNode.ball(rb, at: CGPoint(x: 0, y: rb))
        middle = SnowmanNode.ball(rm, at: CGPoint(x: 0, y: rb * 2 + rm * 0.8))
        let headBall = SnowmanNode.ball(rh, at: .zero)
        let leftEye = shape(SKShapeNode(circleOfRadius: max(0.6, rh * 0.12)), .black, at: CGPoint(x: -rh * 0.35, y: rh * 0.25), z: 0.2)
        let rightEye = shape(SKShapeNode(circleOfRadius: max(0.6, rh * 0.12)), .black, at: CGPoint(x: rh * 0.35, y: rh * 0.25), z: 0.2)
        let nose = SKShapeNode()
        let np = CGMutablePath()
        np.move(to: CGPoint(x: 0, y: rh * 0.12))
        np.addLine(to: CGPoint(x: rh * 0.9, y: -rh * 0.05))
        np.addLine(to: CGPoint(x: 0, y: -rh * 0.2))
        np.closeSubpath()
        nose.path = np
        _ = shape(nose, .orange, z: 0.3)
        let hatParts = [
            shape(SKShapeNode(rectOf: CGSize(width: rh * 2.4, height: rh * 0.35), cornerRadius: 0.5), .black, at: CGPoint(x: 0, y: rh * 0.85)),
            shape(SKShapeNode(rectOf: CGSize(width: rh * 1.5, height: rh * 1.3), cornerRadius: 0.5), .black, at: CGPoint(x: 0, y: rh * 1.6)),
            shape(SKShapeNode(rectOf: CGSize(width: rh * 1.5, height: rh * 0.3)), Palette.beanie, at: CGPoint(x: 0, y: rh * 1.15), z: 0.1),
        ]
        hatRest = 0

        let scarf = shape(SKShapeNode(rectOf: CGSize(width: rm * 1.9, height: max(1.5, rh * 0.45)), cornerRadius: 1),
                          Palette.beanie, at: CGPoint(x: 0, y: rb * 2 + rm * 1.55), z: 0.5)
        let tail = shape(SKShapeNode(rectOf: CGSize(width: max(1.5, rh * 0.4), height: rm * 0.9), cornerRadius: 0.8),
                         Palette.beanie, at: CGPoint(x: rm * 0.5, y: rb * 2 + rm * 1.1), z: 0.5)
        extras = [leftEye, rightEye, nose, scarf, tail]
        super.init()
        head.position = CGPoint(x: 0, y: rb * 2 + rm * 1.6 + rh * 0.8)
        for part in [headBall, leftEye, rightEye, nose] { head.addChild(part) }
        for part in hatParts { hat.addChild(part) }
        hat.zPosition = 0.4
        head.addChild(hat)
        for part in [bottom, middle, head, scarf, tail] as [SKNode] { addChild(part) }
        setProgress(0)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// 0...1. Each ball grows in its own stretch of the range, accessories come last.
    func setProgress(_ p: CGFloat) {
        func span(_ a: CGFloat, _ b: CGFloat) -> CGFloat { max(0, min(1, (p - a) / (b - a))) }
        bottom.setScale(span(0, 0.45))
        middle.setScale(span(0.45, 0.75))
        head.setScale(span(0.75, 0.92))
        let dress = span(0.92, 1)
        for part in extras { part.alpha = dress }
        hat.alpha = dress
        hat.position.y = hatRest + (1 - dress) * height * 0.4
    }

    /// Where the balls are, for breaking it into clumps (local coordinates).
    var ballCentres: [(CGPoint, CGFloat)] {
        [(bottom.position, bottom.frame.width / 2), (middle.position, middle.frame.width / 2),
         (head.position, head.frame.width / 2)].filter { $0.1 > 0.5 }
    }

    private static func ball(_ r: CGFloat, at p: CGPoint) -> SKShapeNode {
        let b = SKShapeNode(circleOfRadius: r)
        b.fillColor = Palette.snow
        b.strokeColor = Palette.snowEdge
        b.lineWidth = 0.7
        b.position = p
        return b
    }
}
