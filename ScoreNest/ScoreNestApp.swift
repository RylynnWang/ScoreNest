import SwiftUI
import SwiftData

@main
struct ScoreNestApp: App {

    var body: some Scene {
        WindowGroup {
            ScoreListView()
        }
        .modelContainer(for: MusicScore.self)
    }
}
