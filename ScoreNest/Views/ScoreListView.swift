//
//  ContentView.swift
//  ScoreNest
//
//  Created by 王御嘉 on 2025/10/30.
//

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
                }
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
}

#Preview(traits: .musicScoresSampleData) {
    ScoreListView()
}
