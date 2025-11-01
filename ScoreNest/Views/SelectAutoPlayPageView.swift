import SwiftUI
import SwiftData

struct SelectAutoPlayPageView: View {
    let score: MusicScore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var orderedPages: [ScorePage] {
        score.pages.sorted { $0.pageNumber < $1.pageNumber }
    }

    var body: some View {
        List {
            ForEach(orderedPages) { page in
                NavigationLink(destination: destinationView(for: page)) {
                    ScorePageThumbnailView(page: page)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        addWholePageSegment(page)
                    } label: {
                        Label("Add Entire Page", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
                .contextMenu {
                    Button {
                        addWholePageSegment(page)
                    } label: {
                        Label("Add Entire Page", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
        }
        .navigationTitle("Select Score Page")
        // Keep the system default back button; do not customize the top-left button
    }

    private func destinationView(for page: ScorePage) -> some View {
        if let timeline = score.autoPlayTimeline {
            return AnyView(CutImageForAutoPlayView(page: page, timeline: timeline))
        } else {
            return AnyView(Text("Timeline not initialized").foregroundStyle(.secondary))
        }
    }

    private func addWholePageSegment(_ page: ScorePage) {
        guard let timeline = score.autoPlayTimeline else { return }
        let nextOrder = (timeline.segments.map { $0.order }.max() ?? 0) + 1
        let seg = AutoPlaySegment(
            sourcePage: page,
            cropRectNormalized: RectSpec(x: 0, y: 0, width: 1, height: 1),
            speedFactor: 1.0,
            order: nextOrder,
            timeline: timeline
        )
        timeline.segments.append(seg)
        modelContext.insert(seg)
        do {
            try modelContext.save()
        } catch {
            print("Failed to add entire page segment: \(error)")
        }
    }
}