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
        // 1) Try asset catalog
        if let img = UIImage(named: named) { return img }
        
        // 2) Absolute path
        if FileManager.default.fileExists(atPath: named) {
            return UIImage(contentsOfFile: named)
        }
        
        // 3) Relative path under Application Support
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let direct = appSupport.appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: direct.path) {
                return UIImage(contentsOfFile: direct.path)
            }
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
    let page = MusicScore.sampleScores.first?.pages.first
    ScorePageView(page: page!)
}
