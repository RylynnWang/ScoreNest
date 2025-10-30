import SwiftUI
import SwiftData

struct MusicScoresSampleData: PreviewModifier {

    static func makeSharedContext() async throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MusicScore.self, configurations: configuration)

        // Insert sample data into the in-memory context
        MusicScore.sampleScores.forEach { container.mainContext.insert($0) }
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var musicScoresSampleData: Self = .modifier(MusicScoresSampleData())
}
