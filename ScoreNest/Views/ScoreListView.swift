import SwiftUI
import SwiftData

struct ScoreListView: View {
    @Query(sort: \MusicScore.createdAt, order: .reverse) private var scores: [MusicScore]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isCleaningUnusedImages: Bool = false
    @State private var showCleanupResult: Bool = false
    @State private var cleanupResultMessage: String = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(scores) { score in
                    NavigationLink(destination: ScoreView(score: score)) {
                        HStack{
                            Text(score.title)
                            Spacer()
                            Text(score.createdAt, format: .dateTime
                                .year()
                                .month(.defaultDigits)
                                .day()
                                .hour(.twoDigits(amPM: .omitted))
                                .minute(.twoDigits)
                                .second(.twoDigits)
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    Menu {
                        Button(action: addNewScore) {
                            Label("新建乐谱", systemImage: "plus")
                        }
                        Button(action: cleanUnusedImages) {
                            Label("清除未使用图片", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("更多操作")
                    .disabled(isCleaningUnusedImages)
                }
            }
            .disabled(isCleaningUnusedImages)
            .overlay {
                if isCleaningUnusedImages {
                    ZStack {
                        Color.black.opacity(0.06).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在清理未使用图片…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.ultraThickMaterial)
                        .cornerRadius(12)
                    }
                }
            }
            .alert("清理完成", isPresented: $showCleanupResult) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(cleanupResultMessage)
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
    
    // MARK: - 清理未使用的图片
    private func cleanUnusedImages() {
        guard !isCleaningUnusedImages else { return }
        isCleaningUnusedImages = true
        Task {
            let usedFileNames: Set<String> = Set(
                scores.flatMap { score in
                    score.pages.map { page in
                        // 取最后一个路径组件，支持 "ScoreNestImages/UUID.ext" 或绝对路径
                        let comps = page.imageFileName.split(separator: "/")
                        return comps.last.map(String.init) ?? page.imageFileName
                    }
                }
            )

            let fm = FileManager.default
            var deletedCount = 0
            var failedFiles: [String] = []

            do {
                guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "ScoreNest", code: 2001, userInfo: [NSLocalizedDescriptionKey: "无法定位 Application Support 目录"]) 
                }
                let imagesDir = appSupport.appendingPathComponent("ScoreNestImages", isDirectory: true)

                if fm.fileExists(atPath: imagesDir.path) {
                    let urls = try fm.contentsOfDirectory(
                        at: imagesDir,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )

                    for url in urls {
                        let name = url.lastPathComponent
                        if !usedFileNames.contains(name) {
                            do {
                                try fm.removeItem(at: url)
                                deletedCount += 1
                            } catch {
                                failedFiles.append(name)
                            }
                        }
                    }
                }

                await MainActor.run {
                    if failedFiles.isEmpty {
                        cleanupResultMessage = deletedCount > 0 ? "已删除 \(deletedCount) 张未使用图片。" : "没有发现未使用图片。"
                    } else {
                        cleanupResultMessage = "已删除 \(deletedCount) 张未使用图片，以下文件删除失败：\n" + failedFiles.joined(separator: "\n")
                    }
                    showCleanupResult = true
                }
            } catch {
                await MainActor.run {
                    cleanupResultMessage = "清理失败：" + error.localizedDescription
                    showCleanupResult = true
                }
            }

            await MainActor.run {
                isCleaningUnusedImages = false
            }
        }
    }
}

#Preview(traits: .musicScoresSampleData) {
    ScoreListView()
}
