import SwiftUI
import SwiftData

struct EditScoreView: View {
    let score: MusicScore

    @State private var title = ""
    @State private var pages: [ScorePage] = []

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(score: MusicScore) {
        self.score = score
        _title = State(initialValue: score.title)
        _pages = State(initialValue: score.pages)
    }

    var body: some View {
        Form {
            Section(header: Text("乐谱标题")) {
                TextField("请输入乐谱标题", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }
            Section(header: Text("乐谱页面")) {
                Text("当前乐谱页面数量: \(pages.count)")
                    .foregroundStyle(.secondary)
                
                ForEach(pages.sorted { $0.pageNumber < $1.pageNumber }) { page in
                    ScorePageThumbnailView(page: page)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletePageLocally(page)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deletePageLocally(page)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("编辑乐谱")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("确定") {
                    do {
                        try saveEdits()
                        dismiss()
                    } catch {
                        print("保存失败: \(error)")
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .tint(.blue)
            }
        }
    }

    private func saveEdits() throws {
        // 在保存前根据当前视图顺序校准页码，保证连续性
        renumberPagesAccordingToViewOrder()
        score.title = title
        
        // 同步删除：将当前状态中不存在的页面从模型中删除
        let remainingIDs = Set(pages.map { $0.id })
        let toDelete = score.pages.filter { !remainingIDs.contains($0.id) }
        for p in toDelete {
            modelContext.delete(p)
        }
        
        try modelContext.save()
    }
    
    private func deletePageLocally(_ page: ScorePage) {
        withAnimation {
            pages.removeAll { $0.id == page.id }
            // 删除后根据当前列表的显示顺序重新编号页码
            renumberPagesAccordingToViewOrder()
        }
    }
    
    private func renumberPagesAccordingToViewOrder() {
        // 当前视图的顺序与 ForEach 一致：按 pageNumber 升序
        let ordered = pages.sorted { $0.pageNumber < $1.pageNumber }
        for (index, p) in ordered.enumerated() {
            p.pageNumber = index + 1
        }
        // 赋值以触发视图刷新（虽然 ForEach 会再次排序，但可确保状态更新）
        pages = ordered
    }
    
}

#Preview(traits: .musicScoresSampleData) {
    @Previewable @Query(sort: \MusicScore.createdAt, order: .reverse) var scores: [MusicScore]
    EditScoreView(score: MusicScore.sampleScores.first!)
}
