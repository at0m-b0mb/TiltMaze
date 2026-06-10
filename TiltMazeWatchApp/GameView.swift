import SwiftUI

struct GameView: View {
    @EnvironmentObject private var game: MazeGame
    @State private var dragging = false

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    // On device, gravity steers; while dragging (or in the
                    // Simulator), the drag gesture provides the tilt instead.
                    if !dragging {
                        if game.usesMotion { game.applyMotionTilt() } else { game.neutralTilt() }
                    }
                    game.advance(to: timeline.date, size: size)
                    MazeRenderer.draw(game: game, context: &context, size: size)
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragging = true
                        game.setDragTilt(CGVector(dx: v.translation.width / 55,
                                                  dy: v.translation.height / 55))
                    }
                    .onEnded { _ in dragging = false; game.neutralTilt() }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button { Haptic.uiTap(); game.showLevels() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 5)
                    .padding(.top, 2)
                    Spacer()
                }
                Spacer()
            }

            if game.won { WinOverlay().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.2), value: game.won)
    }
}

private struct WinOverlay: View {
    @EnvironmentObject private var game: MazeGame
    private let star = Color(.sRGB, red: 1, green: 0.82, blue: 0.25, opacity: 1)
    private let cyan = Color(.sRGB, red: 0.4, green: 0.9, blue: 1.0, opacity: 1)

    var body: some View {
        ZStack {
            Color.black.opacity(0.74).ignoresSafeArea()
            VStack(spacing: 5) {
                Text(game.earnedStars >= 3 ? "PERFECT!" : "SOLVED")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(game.earnedStars >= 3 ? star : .white)

                HStack(spacing: 7) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= game.justLit ? "star.fill" : "star")
                            .font(.system(size: i == 2 ? 28 : 23, weight: .bold))
                            .foregroundStyle(i <= game.justLit ? star : .white.opacity(0.3))
                            .scaleEffect(i <= game.justLit ? 1.0 : 0.7)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: game.justLit)
                    }
                }
                .padding(.vertical, 2)

                Text(String(format: "%.1fs · par %.0fs", game.timer, game.currentLevel.par))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 8) {
                    Button { Haptic.uiTap(); game.showLevels() } label: {
                        Image(systemName: "square.grid.2x2.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { Haptic.uiTap(); game.replay() } label: {
                        Image(systemName: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { Haptic.uiTap(); game.nextLevel() } label: {
                        Image(systemName: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cyan)
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
        }
    }
}
