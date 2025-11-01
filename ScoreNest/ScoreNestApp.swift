import SwiftUI
import SwiftData

@main
struct ScoreNestApp: App {

    var body: some Scene {
        WindowGroup {
            ScoreListView()
                .task { ensureDocumentsPlaceholder() }
        }
        .modelContainer(for: MusicScore.self)
    }

    private func ensureDocumentsPlaceholder() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let placeholderName = String(localized: "Put scores.appdata here to import")
        let placeholderURL = documents.appendingPathComponent(placeholderName, isDirectory: false)
        if !fm.fileExists(atPath: placeholderURL.path) {
            _ = fm.createFile(atPath: placeholderURL.path, contents: nil, attributes: nil)
        }
    }
}
