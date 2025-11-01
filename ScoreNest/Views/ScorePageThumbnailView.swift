import SwiftUI
import SwiftData

struct ScorePageThumbnailView: View {
    let page: ScorePage

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 90, height: 125)
                .clipped()
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(page.pageNumber)")
                    .font(.headline)
                if let note = page.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                // Text(page.imageFileName)
                //     .font(.caption)
                //     .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        Group {
            if let uiImage = loadUIImage(named: page.imageFileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.15)
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadUIImage(named: String) -> UIImage? {
        // 1) Try asset catalog by name
        if let img = UIImage(named: named) { return img }

        // 2) If it's an absolute file path
        if FileManager.default.fileExists(atPath: named) {
            return UIImage(contentsOfFile: named)
        }

        // 3) Try relative path within Application Support
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            // Direct relative path
            let direct = appSupport.appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: direct.path) {
                return UIImage(contentsOfFile: direct.path)
            }

            // Our default images subdirectory
            let nested = appSupport
                .appendingPathComponent("ScoreNestImages", isDirectory: true)
                .appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: nested.path) {
                return UIImage(contentsOfFile: nested.path)
            }
        }

        return nil
    }
}

#Preview {
    let page = MusicScore.sampleScores.first!.pages.first!
    List {
        ScorePageThumbnailView(page: page)
    }
}