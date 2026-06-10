import SwiftUI

/// Stateless maze renderer. `@MainActor` (the `Canvas` closure is main-actor
/// isolated and reads the `@MainActor` engine).
@MainActor
enum MazeRenderer {

    static func draw(game g: MazeGame, context ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(col(0.03, 0.04, 0.07)))

        let m = g.maze
        let o = g.origin, cell = g.cell

        // maze floor panel
        let panel = CGRect(x: o.x, y: o.y, width: cell * CGFloat(m.cols), height: cell * CGFloat(m.rows))
        ctx.fill(Path(roundedRect: panel.insetBy(dx: -3, dy: -3), cornerRadius: 6),
                 with: .color(col(0.06, 0.09, 0.13)))

        // holes
        for hi in m.holes {
            let c = g.cellCenter(hi)
            ctx.fill(circle(c, cell * 0.3), with: .radialGradient(
                Gradient(colors: [col(0, 0, 0), col(0.05, 0.05, 0.08)]),
                center: c, startRadius: 1, endRadius: cell * 0.32))
            ctx.stroke(circle(c, cell * 0.3), with: .color(col(0.2, 0.1, 0.1, 0.6)), lineWidth: 1)
        }

        // goal portal
        let goal = g.cellCenter(m.goal)
        let pulse = 1 + CGFloat(sin(Double(g.timer) * 4)) * 0.12
        ctx.fill(circle(goal, cell * 0.42 * pulse), with: .radialGradient(
            Gradient(colors: [col(0.3, 1, 0.5, 0.5), col(0.3, 1, 0.5, 0)]),
            center: goal, startRadius: 1, endRadius: cell * 0.5 * pulse))
        ctx.stroke(circle(goal, cell * 0.3), with: .color(col(0.4, 1, 0.6)), lineWidth: 2)
        ctx.fill(circle(goal, cell * 0.12), with: .color(col(0.7, 1, 0.8)))

        // walls (one path, stroked twice for a glow)
        var walls = Path()
        for r in 0...m.rows {
            for c in 0..<m.cols where m.hWalls[r][c] {
                let y = o.y + CGFloat(r) * cell
                walls.move(to: CGPoint(x: o.x + CGFloat(c) * cell, y: y))
                walls.addLine(to: CGPoint(x: o.x + CGFloat(c + 1) * cell, y: y))
            }
        }
        for r in 0..<m.rows {
            for c in 0...m.cols where m.vWalls[r][c] {
                let x = o.x + CGFloat(c) * cell
                walls.move(to: CGPoint(x: x, y: o.y + CGFloat(r) * cell))
                walls.addLine(to: CGPoint(x: x, y: o.y + CGFloat(r + 1) * cell))
            }
        }
        ctx.stroke(walls, with: .color(col(0.2, 0.8, 1.0, 0.28)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        ctx.stroke(walls, with: .color(col(0.4, 0.9, 1.0)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // ball trail
        for (i, p) in g.trail.enumerated() {
            let a = Double(i) / Double(max(g.trail.count, 1))
            ctx.fill(circle(p, g.ballRadius * CGFloat(0.3 + a * 0.5)), with: .color(col(0.8, 0.95, 1.0, a * 0.35)))
        }

        // ball
        let b = g.ball
        let r = g.ballRadius
        ctx.fill(circle(b, r * 1.7), with: .radialGradient(
            Gradient(colors: [col(0.6, 0.95, 1.0, 0.5), col(0.6, 0.95, 1.0, 0)]),
            center: b, startRadius: 1, endRadius: r * 1.7))
        ctx.fill(circle(b, r), with: .radialGradient(
            Gradient(colors: [col(1, 1, 1), col(0.4, 0.8, 1.0)]),
            center: CGPoint(x: b.x - r * 0.3, y: b.y - r * 0.3), startRadius: 0.5, endRadius: r * 1.3))

        // fell-in flash
        if g.fellFlash > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(col(0.9, 0.15, 0.15, Double(g.fellFlash) * 0.4)))
        }

        drawHUD(g, &ctx, size: size)
    }

    private static func drawHUD(_ g: MazeGame, _ ctx: inout GraphicsContext, size: CGSize) {
        // timer (top-right)
        ctx.draw(Text(String(format: "%.1f", g.timer)).font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white), at: CGPoint(x: size.width - 7, y: 4), anchor: .topTrailing)
        ctx.draw(Text("LV \(g.currentIndex + 1)").font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(col(0.4, 0.9, 1.0, 0.85)), at: CGPoint(x: size.width - 8, y: 21), anchor: .topTrailing)

        // tilt indicator (bottom-right): a small arrow showing current gravity/drag
        let t = g.tilt
        let mag = hypot(t.dx, t.dy)
        if mag > 0.06 {
            let ctr = CGPoint(x: size.width - 16, y: size.height - 16)
            let dir = CGPoint(x: t.dx / mag, y: t.dy / mag)
            let tip = CGPoint(x: ctr.x + dir.x * 9, y: ctr.y + dir.y * 9)
            ctx.stroke(circle(ctr, 10), with: .color(col(0.4, 0.9, 1.0, 0.3)), lineWidth: 1)
            var arrow = Path()
            arrow.move(to: ctr); arrow.addLine(to: tip)
            ctx.stroke(arrow, with: .color(col(0.5, 1, 0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(circle(tip, 2), with: .color(col(0.7, 1, 0.8)))
        }
    }

    private static func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
