//
//  ScoreNestApp.swift
//  ScoreNest
//
//  Created by 王御嘉 on 2025/10/30.
//

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
