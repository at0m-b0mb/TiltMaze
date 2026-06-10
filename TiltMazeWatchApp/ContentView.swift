import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: MazeGame

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch game.phase {
            case .title:       TitleView()
            case .levelSelect: LevelSelectView()
            case .playing:     GameView()
            }
        }
    }
}

struct TitleView: View {
    @EnvironmentObject private var game: MazeGame
    private let cyan = Color(.sRGB, red: 0.4, green: 0.9, blue: 1.0, opacity: 1)

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 26))
                .foregroundStyle(cyan)
                .padding(.bottom, 3)

            Text("TILT")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("MAZE")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(7)
                .foregroundStyle(cyan)

            if game.totalStars > 0 {
                Label("\(game.totalStars) / \(game.maxStars)", systemImage: "star.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.sRGB, red: 1, green: 0.82, blue: 0.25, opacity: 1))
                    .padding(.top, 3)
            }

            Button {
                Haptic.uiTap()
                game.showLevels()
            } label: {
                Text("PLAY")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(cyan)
            .padding(.top, 7)

            Text("Tilt your wrist to roll")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 3)
        }
        .padding(.horizontal, 14)
    }
}
