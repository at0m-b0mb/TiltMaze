import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var game: MazeGame

    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 58), spacing: 7)]
    private let star = Color(.sRGB, red: 1, green: 0.82, blue: 0.25, opacity: 1)

    static func worldColor(_ w: Int) -> Color {
        switch w % 4 {
        case 0:  return Color(.sRGB, red: 0.4, green: 0.9, blue: 1.0, opacity: 1)
        case 1:  return Color(.sRGB, red: 0.4, green: 1.0, blue: 0.55, opacity: 1)
        case 2:  return Color(.sRGB, red: 0.7, green: 0.5, blue: 1.0, opacity: 1)
        default: return Color(.sRGB, red: 1.0, green: 0.6, blue: 0.3, opacity: 1)
        }
    }

    private var worldStart: [Int] {
        var s: [Int] = []; var acc = 0
        for w in game.worlds { s.append(acc); acc += w.count }
        return s
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { Haptic.uiTap(); game.showTitle() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Label("\(game.totalStars)", systemImage: "star.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(star)
                }
                ForEach(Array(game.worlds.enumerated()), id: \.offset) { wi, world in
                    section(wi, world, worldStart[wi])
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private func section(_ wi: Int, _ world: World, _ start: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(Self.worldColor(wi)).frame(width: 8, height: 8)
                Text(world.name.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(world.rows)×\(world.cols)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(0..<world.count, id: \.self) { i in
                    LevelChip(index: start + i, label: i + 1)
                }
            }
        }
    }
}

private struct LevelChip: View {
    @EnvironmentObject private var game: MazeGame
    let index: Int
    let label: Int
    private let star = Color(.sRGB, red: 1, green: 0.82, blue: 0.25, opacity: 1)

    var body: some View {
        let unlocked = game.isUnlocked(index)
        let s = game.stars[index]
        let color = LevelSelectView.worldColor(game.levels[index].world)
        Button {
            if unlocked { Haptic.uiTap(); game.play(index: index) } else { Haptic.locked() }
        } label: {
            VStack(spacing: 3) {
                if unlocked {
                    Text("\(label)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { k in
                            Image(systemName: k < s ? "star.fill" : "star")
                                .font(.system(size: 6))
                                .foregroundStyle(k < s ? star : .white.opacity(0.25))
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(height: 22)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(unlocked ? color.opacity(0.16) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(unlocked ? color.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
