import SwiftUI
import SwiftData

struct ScoreListView: View {
    @Query(sort: \MusicScore.createdAt, order: .reverse) private var scores: [MusicScore]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(scores) { score in
                    NavigationLink(destination: ScoreView(score: score)) {
                        HStack{
                            Text(score.title)
                            Spacer()
                            Text("\(score.createdAt)")
                                .font(.footnote)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteScore(score)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteScore(score)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteScores)
            }
            .navigationTitle("乐谱")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addNewScore) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        
    }
    
    private func addNewScore() {
        let newScore = MusicScore(title: "Untitled", pages: [])
        modelContext.insert(newScore)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new score: \(error)")
        }
    }
    
    private func deleteScores(at offsets: IndexSet) {
        for index in offsets {
            let score = scores[index]
            modelContext.delete(score)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete scores: \(error)")
        }
    }
    
    private func deleteScore(_ score: MusicScore) {
        modelContext.delete(score)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete score: \(error)")
        }
    }
}

#Preview(traits: .musicScoresSampleData) {
    ScoreListView()
}
