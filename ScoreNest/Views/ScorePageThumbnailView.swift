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
                Text("第 \(page.pageNumber) 页")
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
        UIImage(named: named)
    }
}

#Preview {
    let page = MusicScore.sampleScores.first!.pages.first!
    List {
        ScorePageThumbnailView(page: page)
    }
}