import SwiftUI
import SwiftData

struct ScorePageView: View {
    let page: ScorePage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = loadUIImage(named: page.imageFileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(uiImage.size.width / uiImage.size.height, contentMode: .fit)
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(page.imageFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .cornerRadius(8)
            }

            Text("第 \(page.pageNumber) 页")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func loadUIImage(named: String) -> UIImage? {
        // Load from asset catalog using asset name (imageset name)
        return UIImage(named: named)
    }
}

#Preview {
    let page = MusicScore.sampleScores.first?.pages.first
    ScorePageView(page: page!)
}
