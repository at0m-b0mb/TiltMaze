import SwiftUI

@main
struct TiltMazeApp: App {
    @StateObject private var game = MazeGame()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
    }
}
