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
            Section(header: Text("Score Title")) {
                TextField("Enter score title", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }
            Section(header: Text("Score Pages")) {
                Text("Current page count: \(pages.count)")
                    .foregroundStyle(.secondary)
                
                if let mode = actionMode, let src = sourcePage(for: mode) {
                    HStack {
                        Text(instructionText(for: mode, source: src))
                            .font(.callout)
                            .foregroundStyle(.blue)
                        Spacer()
                        Button("Cancel Selection") { actionMode = nil }
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
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                actionMode = .swap(sourceID: page.id)
                            } label: {
                                Label("Swap Pages", systemImage: "arrow.left.arrow.right")
                            }
                            Button {
                                actionMode = .moveBefore(sourceID: page.id)
                            } label: {
                                Label("Reorder", systemImage: "arrow.up.to.line")
                            }
                            Button(role: .destructive) {
                                deletePageLocally(page)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Add Images", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.borderless)
            }
        }
        .navigationTitle("Edit Score")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    do {
                        try saveEdits()
                        dismiss()
                    } catch {
                        print("Failed to save: \(error)")
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
        // Before saving, renumber pages according to current view order to ensure continuity
        renumberPagesAccordingToViewOrder()
        score.title = title
        
        // Sync deletions: remove pages not present in the current state from the model
        let remainingIDs = Set(pages.map { $0.id })
        let toDelete = score.pages.filter { !remainingIDs.contains($0.id) }
        for p in toDelete {
            modelContext.delete(p)
        }

        // Sync insertions: insert newly added pages from the current state into the model
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
            // After deletion, renumber pages according to current list order
            renumberPagesAccordingToViewOrder()
            if let mode = actionMode, isSource(page: page, of: mode) { actionMode = nil }
        }
    }
    
    private func renumberPagesAccordingToViewOrder() {
        // Reorder page numbers 1...N according to the current array order
        for (index, p) in pages.enumerated() { p.pageNumber = index + 1 }
    }
    
    // MARK: - Swap / Move
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
            return "Select a target page to swap with page \(source.pageNumber)"
        case .moveBefore:
            return "Select a target page to move page \(source.pageNumber) before it"
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
        // Swap based on current visible order (ascending by page number)
        var ordered = pages.sorted { $0.pageNumber < $1.pageNumber }
        guard let i = ordered.firstIndex(where: { $0.id == sourceID }),
              let j = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        ordered.swapAt(i, j)
        pages = ordered
        renumberPagesAccordingToViewOrder()
        actionMode = nil
    }
    
    private func movePageBefore(sourceID: UUID, targetID: UUID) {
        // Move before target based on current visible order
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
    // Centralize the image subdirectory name to avoid magic strings
    private var imagesSubdirectory: String { "ScoreNestImages" }

    // Relative path builder to avoid direct string concatenation
    private func relativeImagePath(for fileName: String) -> String {
        NSString.path(withComponents: [imagesSubdirectory, fileName])
    }

    private func imagesDirectoryURL() throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ScoreNest", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unable to locate Application Support directory"])
        }
        let dir = appSupport.appendingPathComponent(imagesSubdirectory, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func saveImage(_ image: UIImage, with id: UUID) throws -> String {
        let dir = try imagesDirectoryURL() // .../Application Support/ScoreNestImages
        // Prefer encoding as JPEG; fall back to PNG on failure and update the extension accordingly
        let data: Data
        let ext: String
        if let jpeg = image.jpegData(compressionQuality: 0.90) {
            data = jpeg
            ext = "jpg"
        } else if let png = image.pngData() {
            data = png
            ext = "png"
        } else {
            throw NSError(domain: "ScoreNest", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image data"])
        }

        let fileName = id.uuidString + "." + ext
        // The dir is already .../Application Support/ScoreNestImages, so no additional subdirectory is needed
        let absoluteURL = dir.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: absoluteURL, options: [.atomic])
        return relativeImagePath(for: fileName)
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
                        imageFileName: relativePath, // Store relative path ScoreNestImages/<uuid>.jpg
                        pageNumber: (pages.count + newPages.count + 1)
                    )
                    newPages.append(newPage)
                }
            } catch {
                print("Failed to add image: \(error)")
            }
        }
        if !newPages.isEmpty {
            withAnimation {
                pages.append(contentsOf: newPages)
                renumberPagesAccordingToViewOrder()
            }
        }
        // Clear selection to avoid repeated triggers
        selectedItems = []
    }
}

#Preview(traits: .musicScoresSampleData) {
    @Previewable @Query(sort: \MusicScore.createdAt, order: .reverse) var scores: [MusicScore]
    EditScoreView(score: MusicScore.sampleScores.first!)
}
