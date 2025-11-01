import SwiftUI
import SwiftData

struct ScoreView: View {
    let score: MusicScore
    @State private var showAutoPlayAlert: Bool = false

    var body: some View {
        ZoomableScrollView(minScale: 0.20, maxScale: 5.0) {
            VStack(spacing: 16) {
                ForEach(score.pages.sorted(by: { $0.pageNumber < $1.pageNumber })) { page in
                    ScorePageView(page: page)
                }
            }
            .padding()
        }
        .navigationTitle(score.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    NavigationLink(destination: EditScoreView(score: score)) {
                        Label("Edit Score", systemImage: "pencil")
                    }
                    NavigationLink(destination: EditAutoPlayView(score: score)) {
                        Label("Edit Autoplay", systemImage: "gearshape")
                    }
                    if let tl = score.autoPlayTimeline {
                        NavigationLink(destination: AutoPlayView(timeline: tl)) {
                            Label("Start Autoplay", systemImage: "play.circle")
                        }
                    } else {
                        Button {
                            showAutoPlayAlert = true
                        } label: {
                            Label("Start Autoplay", systemImage: "play.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Please edit autoplay first", isPresented: $showAutoPlayAlert) {
            Button("OK") {}
        }
    }
}

#Preview {
    ScoreView(score:MusicScore.sampleScores.first!)
}
