import SwiftUI
import SwiftData
import PhotosUI

struct EditScoreView: View {
    let score: MusicScore

    @State private var title = ""
    @State private var pages: [ScorePage] = []
    @State private var actionMode: ActionMode? = nil
    @State private var selectedItems: [PhotosPickerItem] = []

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
                
                if let mode = actionMode, let src = sourcePage(for: mode) {
                    HStack {
                        Text(instructionText(for: mode, source: src))
                            .font(.callout)
                            .foregroundStyle(.blue)
                        Spacer()
                        Button("取消选择") { actionMode = nil }
                            .buttonStyle(.borderless)
                    }
                }
                
                ForEach(pages.sorted { $0.pageNumber < $1.pageNumber }) { page in
                    ScorePageThumbnailView(page: page)
                        .contentShape(Rectangle())
                        .onTapGesture { handleTapOnPage(page) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletePageLocally(page)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                actionMode = .swap(sourceID: page.id)
                            } label: {
                                Label("交换页面", systemImage: "arrow.left.arrow.right")
                            }
                            Button {
                                actionMode = .moveBefore(sourceID: page.id)
                            } label: {
                                Label("调整顺序", systemImage: "arrow.up.to.line")
                            }
                            Button(role: .destructive) {
                                deletePageLocally(page)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("添加图片", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.borderless)
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
        .onChange(of: selectedItems) { _, newItems in
            Task { await handlePickedItems(newItems) }
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

        // 同步新增：将当前状态中新添加的页面插入到模型
        let existingIDs = Set(score.pages.map { $0.id })
        let toInsert = pages.filter { !existingIDs.contains($0.id) }
        for p in toInsert {
            p.score = score
            score.pages.append(p)
            modelContext.insert(p)
        }
        
        try modelContext.save()
    }
    
    private func deletePageLocally(_ page: ScorePage) {
        withAnimation {
            pages.removeAll { $0.id == page.id }
            // 删除后根据当前列表的显示顺序重新编号页码
            renumberPagesAccordingToViewOrder()
            if let mode = actionMode, isSource(page: page, of: mode) { actionMode = nil }
        }
    }
    
    private func renumberPagesAccordingToViewOrder() {
        // 按当前数组顺序重排页码 1...N
        for (index, p) in pages.enumerated() { p.pageNumber = index + 1 }
    }
    
    // MARK: - 交换 / 移动
    private enum ActionMode { case swap(sourceID: UUID), moveBefore(sourceID: UUID) }
    
    private func sourcePage(for mode: ActionMode) -> ScorePage? {
        switch mode {
        case .swap(let id), .moveBefore(let id):
            return pages.first(where: { $0.id == id })
        }
    }
    
    private func isSource(page: ScorePage, of mode: ActionMode) -> Bool {
        switch mode {
        case .swap(let id), .moveBefore(let id):
            return page.id == id
        }
    }
    
    private func instructionText(for mode: ActionMode, source: ScorePage) -> String {
        switch mode {
        case .swap:
            return "选择目标页面，与第 \(source.pageNumber) 页交换"
        case .moveBefore:
            return "选择目标页面，把第 \(source.pageNumber) 页放到其前面"
        }
    }
    
    private func handleTapOnPage(_ target: ScorePage) {
        guard let mode = actionMode, let source = sourcePage(for: mode) else { return }
        guard source.id != target.id else { return }
        withAnimation {
            switch mode {
            case .swap:
                swapPages(sourceID: source.id, targetID: target.id)
            case .moveBefore:
                movePageBefore(sourceID: source.id, targetID: target.id)
            }
        }
    }
    
    private func swapPages(sourceID: UUID, targetID: UUID) {
        // 以当前可见顺序（按页码升序）为基准交换
        var ordered = pages.sorted { $0.pageNumber < $1.pageNumber }
        guard let i = ordered.firstIndex(where: { $0.id == sourceID }),
              let j = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        ordered.swapAt(i, j)
        pages = ordered
        renumberPagesAccordingToViewOrder()
        actionMode = nil
    }
    
    private func movePageBefore(sourceID: UUID, targetID: UUID) {
        // 以当前可见顺序为基准移动到目标之前
        var ordered = pages.sorted { $0.pageNumber < $1.pageNumber }
        guard let from = ordered.firstIndex(where: { $0.id == sourceID }),
              let toOriginal = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        let moving = ordered.remove(at: from)
        var to = toOriginal
        if from < to { to -= 1 }
        ordered.insert(moving, at: to)
        pages = ordered
        renumberPagesAccordingToViewOrder()
        actionMode = nil
    }
    
}

// MARK: - Photos Picker & File Saving
extension EditScoreView {
    private func imagesDirectoryURL() throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ScoreNest", code: 1001, userInfo: [NSLocalizedDescriptionKey: "无法定位 Application Support 目录"])
        }
        let dir = appSupport.appendingPathComponent("ScoreNestImages", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func saveImage(_ image: UIImage, with id: UUID) throws -> String {
        let dir = try imagesDirectoryURL() // .../Application Support/ScoreNestImages
        let relativePath = "ScoreNestImages/" + id.uuidString + ".jpg"
        let absoluteURL = dir.appendingPathComponent(id.uuidString + ".jpg")
        guard let data = image.jpegData(compressionQuality: 0.88) ?? image.pngData() else {
            throw NSError(domain: "ScoreNest", code: 1002, userInfo: [NSLocalizedDescriptionKey: "无法编码图片数据"])
        }
        try data.write(to: absoluteURL, options: [.atomic])
        return relativePath
    }

    private func handlePickedItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var newPages: [ScorePage] = []
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                    let img = UIImage(data: data) {
                    let pageID = UUID()
                    let relativePath = try saveImage(img, with: pageID)
                    let newPage = ScorePage(
                        id: pageID,
                        imageFileName: relativePath, // 存相对路径 ScoreNestImages/<uuid>.jpg
                        pageNumber: (pages.count + newPages.count + 1)
                    )
                    newPages.append(newPage)
                }
            } catch {
                print("添加图片失败: \(error)")
            }
        }
        if !newPages.isEmpty {
            withAnimation {
                pages.append(contentsOf: newPages)
                renumberPagesAccordingToViewOrder()
            }
        }
        // 清空选择，避免重复触发
        selectedItems = []
    }
}

#Preview(traits: .musicScoresSampleData) {
    @Previewable @Query(sort: \MusicScore.createdAt, order: .reverse) var scores: [MusicScore]
    EditScoreView(score: MusicScore.sampleScores.first!)
}
