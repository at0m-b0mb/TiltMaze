import SwiftUI

/// Tilt Maze engine. Level-select / progression is `@Published` (turn-based);
/// the ball physics is `private(set)` per-frame state advanced by the
/// `TimelineView` in `GameView`. Collisions are resolved with sub-stepping so
/// the ball can never tunnel through a wall.
@MainActor
final class MazeGame: ObservableObject {

    @Published private(set) var phase: GamePhase = .title
    @Published private(set) var currentIndex = 0
    @Published private(set) var won = false
    @Published private(set) var earnedStars = 0
    @Published private(set) var justLit = 0
    @Published private(set) var stars: [Int] = []
    @Published private(set) var unlockedCount = 1

    let worlds: [World]
    let levels: [Level]

    // Per-frame state (renderer reads)
    private(set) var maze: Maze
    private(set) var ball = CGPoint.zero
    private(set) var vel = CGVector.zero
    private(set) var screen = CGSize(width: 184, height: 224)
    private(set) var origin = CGPoint.zero
    private(set) var cell: CGFloat = 20
    private(set) var ballRadius: CGFloat = 6
    private(set) var timer: Double = 0
    private(set) var fellFlash: CGFloat = 0
    private(set) var bumpFlash: CGFloat = 0
    private(set) var trail: [CGPoint] = []

    private let motion = MotionManager()
    private var tiltX: CGFloat = 0
    private var tiltY: CGFloat = 0

    private var needsPlace = false
    private var demoBallCell: Int?
    private var bumpCD: CGFloat = 0
    private var lastDate: Date?
    private let starsKey = "TiltMaze.stars.v1"
    private let unlockedKey = "TiltMaze.unlocked.v1"

    var currentLevel: Level { levels[currentIndex] }
    var totalStars: Int { stars.reduce(0, +) }
    var maxStars: Int { levels.count * 3 }
    var usesMotion: Bool { motion.available }

    init() {
        let defs = [
            World(name: "Drift", rows: 5, cols: 5, count: 8,  holes: 0),
            World(name: "Grid",  rows: 6, cols: 6, count: 10, holes: 1),
            World(name: "Vault", rows: 7, cols: 7, count: 10, holes: 2),
            World(name: "Core",  rows: 8, cols: 8, count: 8,  holes: 3),
        ]
        var built: [Level] = []
        var gid = 0
        for (wi, w) in defs.enumerated() {
            for k in 0..<w.count {
                let holes = w.holes + (k >= w.count / 2 ? 1 : 0)
                let seed = 0x7A2E &+ UInt64(gid) &* 0x9E3779B1
                let par = Double(w.rows * w.cols) * 0.4 + 2 + Double(holes) * 1.5
                built.append(Level(id: gid, world: wi, rows: w.rows, cols: w.cols,
                                   holes: holes, par: par, seed: seed))
                gid += 1
            }
        }
        worlds = defs
        levels = built

        if let saved = UserDefaults.standard.array(forKey: starsKey) as? [Int], saved.count == built.count {
            stars = saved
        } else {
            stars = Array(repeating: 0, count: built.count)
        }
        unlockedCount = max(1, UserDefaults.standard.integer(forKey: unlockedKey))

        let l0 = built[0]
        maze = MazeFactory.generate(rows: l0.rows, cols: l0.cols, holeCount: l0.holes, seed: l0.seed)

        #if DEBUG
        configureLaunchDemo()
        #endif
    }

    // MARK: Navigation

    func showLevels() { phase = .levelSelect; motion.stop() }
    func showTitle()  { phase = .title; motion.stop() }
    func isUnlocked(_ i: Int) -> Bool { i < unlockedCount }

    func play(index: Int) {
        guard levels.indices.contains(index) else { return }
        currentIndex = index
        let lv = levels[index]
        maze = MazeFactory.generate(rows: lv.rows, cols: lv.cols, holeCount: lv.holes, seed: lv.seed)
        vel = .zero; timer = 0; won = false; earnedStars = 0; justLit = 0
        trail.removeAll()
        needsPlace = true
        phase = .playing
        motion.start()
    }

    func replay() { play(index: currentIndex) }

    func nextLevel() {
        let n = currentIndex + 1
        if levels.indices.contains(n) && isUnlocked(n) { play(index: n) } else { showLevels() }
    }

    // MARK: Control input (set by the view each frame)

    func applyMotionTilt() { tiltX = clamp(CGFloat(motion.gx), -1, 1); tiltY = clamp(CGFloat(-motion.gy), -1, 1) }
    func setDragTilt(_ v: CGVector) { tiltX = clamp(v.dx, -1, 1); tiltY = clamp(v.dy, -1, 1) }
    func neutralTilt() { tiltX = 0; tiltY = 0 }
    var tilt: CGVector { CGVector(dx: tiltX, dy: tiltY) }

    // MARK: Geometry

    private func computeGeometry() {
        let topHUD: CGFloat = 24
        let margin: CGFloat = 7
        let availW = screen.width - margin * 2
        let availH = screen.height - topHUD - margin
        cell = min(availW / CGFloat(maze.cols), availH / CGFloat(maze.rows))
        let mw = cell * CGFloat(maze.cols), mh = cell * CGFloat(maze.rows)
        origin = CGPoint(x: (screen.width - mw) / 2, y: topHUD + (availH - mh) / 2)
        ballRadius = cell * 0.28
    }

    func cellCenter(_ i: Int) -> CGPoint {
        let r = i / maze.cols, c = i % maze.cols
        return CGPoint(x: origin.x + (CGFloat(c) + 0.5) * cell, y: origin.y + (CGFloat(r) + 0.5) * cell)
    }

    private func cellOf(_ p: CGPoint) -> (Int, Int) {
        let c = clamp(Int((p.x - origin.x) / cell), 0, maze.cols - 1)
        let r = clamp(Int((p.y - origin.y) / cell), 0, maze.rows - 1)
        return (r, c)
    }

    // MARK: Step

    func advance(to date: Date, size: CGSize) {
        guard phase == .playing else { lastDate = date; return }
        screen = size
        computeGeometry()
        if needsPlace {
            ball = cellCenter(demoBallCell ?? 0)
            demoBallCell = nil
            vel = .zero
            needsPlace = false
        }
        let dt = min(CGFloat(date.timeIntervalSince(lastDate ?? date)), 1.0 / 30.0)
        lastDate = date
        guard dt > 0 else { return }

        bumpCD = max(0, bumpCD - dt)
        fellFlash = max(0, fellFlash - dt * 2)
        bumpFlash = max(0, bumpFlash - dt * 4)
        guard !won else { return }

        timer += Double(dt)

        let g: CGFloat = 1150
        vel.dx += tiltX * g * dt
        vel.dy += tiltY * g * dt
        let fr = CGFloat(exp(-1.9 * Double(dt)))
        vel.dx *= fr; vel.dy *= fr
        let sp = hypot(vel.dx, vel.dy)
        let maxSp: CGFloat = 250
        if sp > maxSp { vel.dx *= maxSp / sp; vel.dy *= maxSp / sp }

        let sub = 3
        let h = dt / CGFloat(sub)
        for _ in 0..<sub {
            ball.x += vel.dx * h
            ball.y += vel.dy * h
            resolveCollisions()
        }

        trail.append(ball)
        if trail.count > 14 { trail.removeFirst() }

        checkHole()
        if !won { checkGoal() }
    }

    // MARK: Collision

    private func resolveCollisions() {
        let (cr, cc) = cellOf(ball)
        for r in max(0, cr - 1)...min(maze.rows, cr + 2) {
            for c in max(0, cc - 1)...min(maze.cols - 1, cc + 1) { collideH(r, c) }
        }
        for r in max(0, cr - 1)...min(maze.rows - 1, cr + 1) {
            for c in max(0, cc - 1)...min(maze.cols, cc + 2) { collideV(r, c) }
        }
    }

    private func collideH(_ r: Int, _ c: Int) {
        guard r >= 0, r <= maze.rows, c >= 0, c < maze.cols, maze.hWalls[r][c] else { return }
        let y = origin.y + CGFloat(r) * cell
        let x0 = origin.x + CGFloat(c) * cell
        let cx = clamp(ball.x, x0, x0 + cell)
        let dx = ball.x - cx, dy = ball.y - y
        let d = hypot(dx, dy)
        if d < ballRadius { resolve(dx, dy, d, CGVector(dx: 0, dy: ball.y >= y ? 1 : -1)) }
    }

    private func collideV(_ r: Int, _ c: Int) {
        guard r >= 0, r < maze.rows, c >= 0, c <= maze.cols, maze.vWalls[r][c] else { return }
        let x = origin.x + CGFloat(c) * cell
        let y0 = origin.y + CGFloat(r) * cell
        let cy = clamp(ball.y, y0, y0 + cell)
        let dx = ball.x - x, dy = ball.y - cy
        let d = hypot(dx, dy)
        if d < ballRadius { resolve(dx, dy, d, CGVector(dx: ball.x >= x ? 1 : -1, dy: 0)) }
    }

    private func resolve(_ dx: CGFloat, _ dy: CGFloat, _ dist: CGFloat, _ fallback: CGVector) {
        let nx: CGFloat, ny: CGFloat
        if dist > 0.0001 { nx = dx / dist; ny = dy / dist } else { nx = fallback.dx; ny = fallback.dy }
        let push = ballRadius - dist
        ball.x += nx * push; ball.y += ny * push
        let vn = vel.dx * nx + vel.dy * ny
        if vn < 0 {
            let e: CGFloat = 0.12
            vel.dx -= (1 + e) * vn * nx
            vel.dy -= (1 + e) * vn * ny
            if -vn > 95 && bumpCD <= 0 { Haptic.bump(); bumpCD = 0.12; bumpFlash = 1 }
        }
    }

    private func checkHole() {
        for hi in maze.holes where ball.distance(to: cellCenter(hi)) < cell * 0.32 {
            Haptic.fall()
            fellFlash = 1
            timer += 1.5
            ball = cellCenter(0); vel = .zero; trail.removeAll()
            return
        }
    }

    private func checkGoal() {
        if ball.distance(to: cellCenter(maze.goal)) < cell * 0.4 { winLevel() }
    }

    private func winLevel() {
        won = true
        let lv = currentLevel
        let s = timer <= lv.par ? 3 : (timer <= lv.par * 1.7 ? 2 : 1)
        earnedStars = s
        if s > stars[currentIndex] {
            stars[currentIndex] = s
            UserDefaults.standard.set(stars, forKey: starsKey)
        }
        let unlockTo = min(levels.count, currentIndex + 2)
        if unlockTo > unlockedCount {
            unlockedCount = unlockTo
            UserDefaults.standard.set(unlockedCount, forKey: unlockedKey)
        }
        Haptic.win()
        revealStars(s)
    }

    private func revealStars(_ s: Int) {
        justLit = 0
        for i in 1...max(1, s) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.28 * Double(i)) { [weak self] in
                guard let self, self.won, i <= self.earnedStars else { return }
                self.justLit = i
                Haptic.star()
            }
        }
    }
}

#if DEBUG
extension MazeGame {
    /// Jump into a state for screenshots/QA via `TM_DEMO`. Compiled out of Release.
    func configureLaunchDemo() {
        guard let mode = ProcessInfo.processInfo.environment["TM_DEMO"] else { return }
        switch mode {
        case "levels":
            unlockedCount = 16
            let pat = [3, 2, 3, 3, 2, 3, 1, 2, 3, 2, 3, 1, 2, 3]
            for i in 0..<min(pat.count, stars.count) { stars[i] = pat[i] }
            phase = .levelSelect
        case "play":
            unlockedCount = max(unlockedCount, 16)
            play(index: 12)
            timer = 7.4
            demoBallCell = 8
        case "win":
            unlockedCount = max(unlockedCount, 16)
            play(index: 5)
            timer = 8.2
            won = true; earnedStars = 3; justLit = 3
        default:
            break
        }
    }
}
#endif
