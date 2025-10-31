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
                        Label("编辑乐谱", systemImage: "pencil")
                    }
                    NavigationLink(destination: EditAutoPlayView(score: score)) {
                        Label("编辑自动播放", systemImage: "gearshape")
                    }
                    if let tl = score.autoPlayTimeline {
                        NavigationLink(destination: AutoPlayView(timeline: tl)) {
                            Label("开始自动播放", systemImage: "play.circle")
                        }
                    } else {
                        Button {
                            showAutoPlayAlert = true
                        } label: {
                            Label("开始自动播放", systemImage: "play.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("请先编辑自动播放", isPresented: $showAutoPlayAlert) {
            Button("好的") {}
        }
    }
}

#Preview {
    ScoreView(score:MusicScore.sampleScores.first!)
}
