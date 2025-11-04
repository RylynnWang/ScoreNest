import SwiftUI
import SwiftData
import Foundation

struct ScoreListView: View {
    @Query(sort: \MusicScore.createdAt, order: .reverse) private var scores: [MusicScore]
    @Environment(\.modelContext) private var modelContext
    
    private enum SortOption: String, CaseIterable {
        case dateDesc
        case titleAsc
    }

    @State private var sortOption: SortOption = .dateDesc
    @State private var isExportingAppData: Bool = false
    @State private var isImportingAppData: Bool = false
    @State private var showExportResult: Bool = false
    @State private var exportResultMessage: String = ""
    @State private var showImportResult: Bool = false
    @State private var importResultMessage: String = ""
    @State private var exportAlertTitle: String = NSLocalizedString("Export Complete", comment: "Export alert title")
    @State private var importAlertTitle: String = NSLocalizedString("Import Complete", comment: "Import alert title")

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayScores) { score in
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
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteScore(score)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteScores)
            }
            .navigationTitle("Your Scores")
            .animation(.easeInOut(duration: 0.25), value: sortOption)
            .toolbar {
                // Primary add button as a separate, visible action
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addNewScore) {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("New Score")
                    .disabled(isExportingAppData || isImportingAppData)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Sort options
                        Section {
                            Picker("Sort Order", selection: $sortOption) {
                                Label("Sort by Date", systemImage: "calendar").tag(SortOption.dateDesc)
                                Label("Sort by Title", systemImage: "textformat.abc").tag(SortOption.titleAsc)
                            }
                        }
                        Divider()
                        Button(action: exportAppData) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button(action: importAppData) {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("More Actions")
                    .disabled(isExportingAppData || isImportingAppData)
                }
            }
            .disabled(isExportingAppData || isImportingAppData)
            .overlay {
                if isExportingAppData || isImportingAppData {
                    ZStack {
                        Color.black.opacity(0.06).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(isExportingAppData ? "Exporting data…" : "Importing data…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.ultraThickMaterial)
                        .cornerRadius(12)
                    }
                }
            }
            .alert(exportAlertTitle, isPresented: $showExportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportResultMessage)
            }
            .alert(importAlertTitle, isPresented: $showImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importResultMessage)
            }
        }
        
    }
    
    // The list to display based on the current sort option
    private var displayScores: [MusicScore] {
        switch sortOption {
        case .dateDesc:
            return scores.sorted { $0.createdAt > $1.createdAt }
        case .titleAsc:
            return scores.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
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
            let score = displayScores[index]
            modelContext.delete(score)
        }
        do {
            try modelContext.save()
            // Auto cleanup after deletion
            cleanUnusedImagesSilently()
        } catch {
            print("Failed to delete scores: \(error)")
        }
    }
    
    private func deleteScore(_ score: MusicScore) {
        modelContext.delete(score)
        do {
            try modelContext.save()
            // Auto cleanup after deletion
            cleanUnusedImagesSilently()
        } catch {
            print("Failed to delete score: \(error)")
        }
    }
    
    // MARK: - Clean up unused images (silently, no user feedback)
    private func cleanUnusedImagesSilently() {
        Task {
            let usedFileNames: Set<String> = Set(
                scores.flatMap { score in
                    score.pages.map { page in
                        // Get the last path component, supports "ScoreNestImages/UUID.ext" or absolute paths
                        let comps = page.imageFileName.split(separator: "/")
                        return comps.last.map(String.init) ?? page.imageFileName
                    }
                }
            )

            let fm = FileManager.default

            do {
                guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                    return
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
                            try? fm.removeItem(at: url)
                        }
                    }
                }
            } catch {
                // Silently fail, no user notification
                print("Silent cleanup failed: \(error)")
            }
        }
    }

    // MARK: - Export / Import
    private func exportAppData() {
        guard !isExportingAppData else { return }
        isExportingAppData = true
        Task {
            do {
                // Clean unused images before export
                await cleanUnusedImagesSync()
                
                let result = try AppDataIO.exportAll(toDocumentsWithName: "scores.appdata", modelContext: modelContext)
                switch result {
                case .success(let packageURL):
                    await MainActor.run {
                        exportAlertTitle = NSLocalizedString("Export Complete", comment: "Export alert title success")
                        let base = String(
                            format: NSLocalizedString("Exported to %@ in Documents.", comment: "Export success message with file name"),
                            packageURL.lastPathComponent
                        )
                        let tip = NSLocalizedString("You can view it in the Files app.", comment: "Export success follow-up guidance")
                        exportResultMessage = base + " " + tip
                        showExportResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    exportAlertTitle = NSLocalizedString("Export Failed", comment: "Export alert title failure")
                    exportResultMessage = String(
                        format: NSLocalizedString("Export failed: %@", comment: "Export failure with error description"),
                        error.localizedDescription
                    )
                    showExportResult = true
                }
            }
            await MainActor.run { isExportingAppData = false }
        }
    }

    private func importAppData() {
        guard !isImportingAppData else { return }
        isImportingAppData = true
        Task {
            do {
                // Clean unused images before import
                await cleanUnusedImagesSync()
                
                let fm = FileManager.default
                guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "ScoreNest", code: 3001, userInfo: [NSLocalizedDescriptionKey: "无法定位 Documents 目录"]) 
                }
                let packageURL = documents.appendingPathComponent("scores.appdata", isDirectory: true)

                // Pre-check that the target package directory exists; provide a localized error with guidance if missing
                var isDir: ObjCBool = false
                if !fm.fileExists(atPath: packageURL.path, isDirectory: &isDir) || !isDir.boolValue {
                    let errMsg = String(
                        format: NSLocalizedString("Cannot find %@ in Documents. Open the Files app and place the package folder in Documents.", comment: "Missing import package with guidance"),
                        "scores.appdata"
                    )
                    throw NSError(domain: "ScoreNest", code: 3002, userInfo: [NSLocalizedDescriptionKey: errMsg])
                }

                let result = try AppDataIO.importFromPackage(at: packageURL, modelContext: modelContext)
                switch result {
                case .success(let importedScores, let importedPages, let importedSegments):
                    await MainActor.run {
                        importAlertTitle = NSLocalizedString("Import Complete", comment: "Import alert title success")
                        importResultMessage = String(
                            format: NSLocalizedString("Imported %lld scores, %lld pages, %lld segments.", comment: "Import success counts"),
                            importedScores, importedPages, importedSegments
                        )
                        showImportResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    importAlertTitle = NSLocalizedString("Import Failed", comment: "Import alert title failure")
                    importResultMessage = String(
                        format: NSLocalizedString("Import failed: %@", comment: "Import failure with error description"),
                        error.localizedDescription
                    )
                    showImportResult = true
                }
            }
            await MainActor.run { isImportingAppData = false }
        }
    }
    
    // MARK: - Synchronous cleanup helper
    private func cleanUnusedImagesSync() async {
        let usedFileNames: Set<String> = Set(
            scores.flatMap { score in
                score.pages.map { page in
                    let comps = page.imageFileName.split(separator: "/")
                    return comps.last.map(String.init) ?? page.imageFileName
                }
            }
        )

        let fm = FileManager.default

        do {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                return
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
                        try? fm.removeItem(at: url)
                    }
                }
            }
        } catch {
            print("Sync cleanup failed: \(error)")
        }
    }
}

//#Preview(traits: .musicScoresSampleData) {
//    ScoreListView()
//}
