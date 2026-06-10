import CoreGraphics

enum GamePhase {
    case title
    case levelSelect
    case playing
}

/// Deterministic RNG (SplitMix64) so generated mazes are identical every launch.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A perfect maze on an `rows × cols` grid.
///
/// Walls live on the grid lines:
/// - `hWalls[r][c]` is the horizontal wall on the top edge of cell `(r,c)`
///   (line `y = r`). Size `(rows+1) × cols`.
/// - `vWalls[r][c]` is the vertical wall on the left edge of cell `(r,c)`
///   (line `x = c`). Size `rows × (cols+1)`.
struct Maze {
    let rows: Int
    let cols: Int
    var hWalls: [[Bool]]
    var vWalls: [[Bool]]
    var holes: [Int]      // cell indices r*cols + c
    var goal: Int         // cell index

    func index(_ r: Int, _ c: Int) -> Int { r * cols + c }
}

enum MazeFactory {
    /// Carve a perfect maze with an iterative recursive-backtracker, then sprinkle
    /// a few holes on non-start / non-goal cells. Deterministic for a given seed.
    static func generate(rows: Int, cols: Int, holeCount: Int, seed: UInt64) -> Maze {
        var rng = SeededRNG(seed: seed)
        var h = Array(repeating: Array(repeating: true, count: cols), count: rows + 1)
        var v = Array(repeating: Array(repeating: true, count: cols + 1), count: rows)
        var visited = Array(repeating: false, count: rows * cols)

        var stack: [(Int, Int)] = [(0, 0)]
        visited[0] = true
        while let (r, c) = stack.last {
            var nbrs: [(Int, Int, Int)] = []   // (r, c, dir): 0=N 1=E 2=S 3=W
            if r > 0,        !visited[(r - 1) * cols + c] { nbrs.append((r - 1, c, 0)) }
            if c < cols - 1, !visited[r * cols + c + 1]   { nbrs.append((r, c + 1, 1)) }
            if r < rows - 1, !visited[(r + 1) * cols + c] { nbrs.append((r + 1, c, 2)) }
            if c > 0,        !visited[r * cols + c - 1]   { nbrs.append((r, c - 1, 3)) }
            if nbrs.isEmpty { stack.removeLast(); continue }
            let pick = nbrs[Int(rng.next() % UInt64(nbrs.count))]
            switch pick.2 {
            case 0:  h[r][c] = false        // north edge of (r,c)
            case 1:  v[r][c + 1] = false    // east edge of (r,c)
            case 2:  h[r + 1][c] = false    // south edge of (r,c)
            default: v[r][c] = false        // west edge of (r,c)
            }
            visited[pick.0 * cols + pick.1] = true
            stack.append((pick.0, pick.1))
        }

        let goal = rows * cols - 1
        var holes: [Int] = []
        var tries = 0
        while holes.count < holeCount && tries < 300 {
            tries += 1
            let i = Int(rng.next() % UInt64(rows * cols))
            if i != 0 && i != goal && !holes.contains(i) { holes.append(i) }
        }
        return Maze(rows: rows, cols: cols, hWalls: h, vWalls: v, holes: holes, goal: goal)
    }
}

struct Level: Identifiable {
    let id: Int
    let world: Int
    let rows: Int
    let cols: Int
    let holes: Int
    let par: Double      // seconds for 3 stars
    let seed: UInt64
}

struct World {
    let name: String
    let rows: Int
    let cols: Int
    let count: Int
    let holes: Int
}

@inline(__always) func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}
