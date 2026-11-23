import AppKit
import SpriteKit

/// Frost on the "glass" of the screen. It creeps in from the edges and corners while
/// you're away, with ice crystals branching inward, and melts back when you return.
/// Your pointer is warm: it melts the frost around it.
final class FrostLayer {
    unowned let scene: WeatherOverlayScene

    /// 0 = no frost, 1 = frost has reached the middle of the screen.
    private(set) var progress: CGFloat = 0
    private var growRate: CGFloat = 0        // progress per second while freezing
    private var melting = false
    private var demoTimer: CGFloat?

    private var sprite: SKSpriteNode?
    private var progressUniform = SKUniform(name: "u_progress", float: 0)
    private var wipeUniform: SKUniform?

    // Where the pointer has melted the frost: a small grid, 0 = frozen, 1 = clear.
    private let gridW = 96, gridH = 60
    private var wipe: [Float]
    private var wipeDirty = false
    private var wipeTimer: CGFloat = 0

    var isActive: Bool { progress > 0.001 || growRate > 0 }

    init(scene: WeatherOverlayScene) {
        self.scene = scene
        wipe = Array(repeating: 0, count: gridW * gridH)
    }

    // MARK: - Control

    /// Start freezing. `minutes` = how long until the frost reaches the middle.
    func startFreezing(minutes: Double) {
        melting = false
        growRate = CGFloat(1 / (minutes * 60))
        ensureSprite()
    }

    /// You're back: the frost melts back toward the edges over a few seconds.
    func melt() {
        growRate = 0
        demoTimer = nil
        melting = progress > 0
    }

    /// Menu demo: freezes in about 6 seconds, stays a moment, then melts.
    func demo() {
        for i in wipe.indices { wipe[i] = 0 }
        wipeDirty = true
        startFreezing(minutes: 0.1)
        demoTimer = 9
    }

    // MARK: - Frame loop

    func update(dt: CGFloat) {
        if let t = demoTimer {
            demoTimer = t - dt
            if t - dt <= 0 { melt() }
        }
        if growRate > 0 { progress = min(1, progress + growRate * dt) }
        if melting {
            progress = max(0, progress - dt / 6)
            if progress == 0 { melting = false }
        }
        guard progress > 0.001 else {
            if sprite != nil { tearDown() }
            return
        }
        ensureSprite()
        progressUniform.floatValue = Float(progress)

        meltAroundPointer(dt: dt)
        wipeTimer += dt
        if wipeDirty, wipeTimer > 0.05 {
            wipeTimer = 0
            wipeDirty = false
            wipeUniform?.textureValue = Self.texture(from: wipe, width: gridW, height: gridH)
        }
    }

    /// The warm pointer clears a soft circle that slowly widens while it rests there.
    private func meltAroundPointer(dt: CGFloat) {
        let p = scene.local(scene.cursor)
        let size = scene.screenFrame.size
        guard p.x >= 0, p.y >= 0, p.x <= size.width, p.y <= size.height else { return }
        let gx = p.x / size.width * CGFloat(gridW)
        let gy = (1 - p.y / size.height) * CGFloat(gridH)     // grid row 0 is the top
        let radius: CGFloat = 70 / size.width * CGFloat(gridW)
        let strength = Float(dt * (scene.cursorSpeed > 20 ? 6 : 1.5))
        let r = Int(radius) + 1
        for y in max(0, Int(gy) - r)...min(gridH - 1, Int(gy) + r) {
            for x in max(0, Int(gx) - r)...min(gridW - 1, Int(gx) + r) {
                let d = hypot(CGFloat(x) + 0.5 - gx, (CGFloat(y) + 0.5 - gy) * 1.0)
                guard d < radius else { continue }
                let f = Float(1 - d / radius)
                let i = y * gridW + x
                wipe[i] = min(1, wipe[i] + strength * f)
                wipeDirty = true
            }
        }
    }

    // MARK: - Drawing

    private func ensureSprite() {
        guard sprite == nil else { return }
        let size = scene.screenFrame.size
        let crystals = Self.makeCrystalTexture(size: size)
        let field = Self.makeFieldTexture()
        let wipeTexture = Self.texture(from: wipe, width: gridW, height: gridH)
        let wipeU = SKUniform(name: "u_wipe", texture: wipeTexture)
        wipeUniform = wipeU

        let node = SKSpriteNode(texture: crystals, size: size)
        node.anchorPoint = .zero
        node.position = .zero
        node.zPosition = 10            // on the glass: above everything else
        let shader = SKShader(source: Self.shaderSource)
        shader.uniforms = [progressUniform, SKUniform(name: "u_field", texture: field), wipeU]
        node.shader = shader
        scene.addChild(node)
        sprite = node
    }

    private func tearDown() {
        sprite?.removeFromParent()
        sprite = nil
        wipeUniform = nil
        for i in wipe.indices { wipe[i] = 0 }
    }

    /// Frost appears where the growth field is below `u_progress`, with a soft edge.
    /// A light haze sits under the crystals, thicker near the edges.
    private static let shaderSource = """
    void main() {
        vec2 uv = v_tex_coord;
        float field = texture2D(u_field, uv).r;
        float grown = smoothstep(field - 0.07, field, u_progress);
        float cleared = texture2D(u_wipe, uv).r;
        float amount = grown * (1.0 - cleared);
        float crystal = texture2D(u_texture, uv).a;
        float haze = 0.16 + 0.24 * (1.0 - field);
        float alpha = clamp(crystal * 0.9 + haze, 0.0, 0.88) * amount;
        gl_FragColor = vec4(vec3(0.93, 0.97, 1.0) * alpha, alpha);
    }
    """

    /// Branching ice crystals growing in from the edges, denser in the corners.
    private static func makeCrystalTexture(size: CGSize) -> SKTexture {
        let w = Int(size.width), h = Int(size.height)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return SKTexture()
        }
        ctx.setLineCap(.round)
        let W = CGFloat(w), H = CGFloat(h)

        func branch(from p: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, depth: Int) {
            guard depth > 0, length > 3 else { return }
            // A slightly wobbly line made of a few segments.
            var point = p
            var a = angle
            let segments = 4
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.28 + CGFloat(depth) * 0.1))
            ctx.setLineWidth(width)
            ctx.move(to: point)
            var mids: [(CGPoint, CGFloat)] = []
            for _ in 0..<segments {
                a += .random(in: -0.18...0.18)
                point = CGPoint(x: point.x + cos(a) * length / CGFloat(segments),
                                y: point.y + sin(a) * length / CGFloat(segments))
                ctx.addLine(to: point)
                mids.append((point, a))
            }
            ctx.strokePath()
            // Side branches at frost-like angles.
            for (q, qa) in mids where Bool.random() {
                let side: CGFloat = Bool.random() ? 1 : -1
                branch(from: q, angle: qa + side * .random(in: 0.7...1.1), length: length * .random(in: 0.35...0.55),
                       width: max(0.5, width * 0.65), depth: depth - 1)
            }
            branch(from: point, angle: a + .random(in: -0.3...0.3), length: length * 0.6,
                   width: max(0.5, width * 0.75), depth: depth - 1)
        }

        // Seeds along every edge, pointing inward, plus extra in the corners.
        let perimeter = 2 * (W + H)
        let seeds = Int(perimeter / 22)
        for _ in 0..<seeds {
            let t = CGFloat.random(in: 0..<perimeter)
            let p: CGPoint, inward: CGFloat
            if t < W { p = CGPoint(x: t, y: 0); inward = .pi / 2 }
            else if t < W + H { p = CGPoint(x: W, y: t - W); inward = .pi }
            else if t < 2 * W + H { p = CGPoint(x: t - W - H, y: H); inward = -.pi / 2 }
            else { p = CGPoint(x: 0, y: t - 2 * W - H); inward = 0 }
            branch(from: p, angle: inward + .random(in: -0.7...0.7), length: .random(in: 60...220),
                   width: .random(in: 1...2.2), depth: 4)
        }
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: W, y: 0), CGPoint(x: 0, y: H), CGPoint(x: W, y: H)] {
            let toCentre = atan2(H / 2 - corner.y, W / 2 - corner.x)
            for _ in 0..<14 {
                branch(from: corner, angle: toCentre + .random(in: -0.8...0.8), length: .random(in: 120...320),
                       width: .random(in: 1.5...2.6), depth: 5)
            }
        }
        // Fine frosty speckle.
        for _ in 0..<(w * h / 900) {
            let p = CGPoint(x: .random(in: 0..<W), y: .random(in: 0..<H))
            ctx.setFillColor(CGColor(gray: 1, alpha: .random(in: 0.08...0.3)))
            let r = CGFloat.random(in: 0.4...1.3)
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    /// When each spot freezes: 0 at the edges (and earliest in the corners), 1 in the middle,
    /// with gentle noise so the frost front is uneven.
    private static func makeFieldTexture() -> SKTexture {
        let w = 160, h = 100
        // Coarse random grid, smoothly interpolated, for the uneven front.
        let cw = 9, ch = 7
        let coarse = (0..<(cw * ch)).map { _ in Float.random(in: 0.7...1.3) }
        func noise(_ u: Float, _ v: Float) -> Float {
            let x = u * Float(cw - 1), y = v * Float(ch - 1)
            let x0 = min(cw - 2, Int(x)), y0 = min(ch - 2, Int(y))
            let fx = x - Float(x0), fy = y - Float(y0)
            let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
            let a = coarse[y0 * cw + x0], b = coarse[y0 * cw + x0 + 1]
            let c = coarse[(y0 + 1) * cw + x0], d = coarse[(y0 + 1) * cw + x0 + 1]
            return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy
        }
        var values = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let u = (Float(x) + 0.5) / Float(w), v = (Float(y) + 0.5) / Float(h)
                let ex = 2 * min(u, 1 - u), ey = 2 * min(v, 1 - v)
                let base = min(ex, ey) * 0.75 + ex * ey * 0.25
                values[y * w + x] = min(1, base * noise(u, v))
            }
        }
        return texture(from: values, width: w, height: h)
    }

    /// A grayscale texture from values in 0...1 (row 0 = top), smoothly filtered.
    private static func texture(from values: [Float], width: Int, height: Int) -> SKTexture {
        var bytes = values.map { UInt8(max(0, min(1, $0)) * 255) }
        let texture: SKTexture = bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
                  let image = ctx.makeImage() else { return SKTexture() }
            return SKTexture(cgImage: image)
        }
        texture.filteringMode = .linear
        return texture
    }
}
