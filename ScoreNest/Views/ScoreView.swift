import SwiftUI
import SwiftData

struct ScoreView: View {
    let score: MusicScore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
                    Button {
                        
                    } label: {
                        Label("编辑自动播放", systemImage: "gearshape")
                    }
                    Button {
                        
                    } label: {
                        Label("开始自动播放", systemImage: "play.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

#Preview {
    ScoreView(score:MusicScore.sampleScores.first!)
}
