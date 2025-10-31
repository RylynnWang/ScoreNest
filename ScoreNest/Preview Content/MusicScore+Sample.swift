import Foundation

extension MusicScore {
    // 动态计算项目根路径：从当前源文件开始向上查找包含 .xcodeproj 的目录
    static let projectBaseRoot: String = {
        let fileURL = URL(fileURLWithPath: #file)
        var dirURL = fileURL.deletingLastPathComponent() // .../ScoreNest/Preview Content
        let fm = FileManager.default

        // 向上查找直到根目录或发现任意 .xcodeproj 目录
        for _ in 0..<24 { // 合理上限，避免极端路径导致无限循环
            let items = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
            if items.contains(where: { $0.hasSuffix(".xcodeproj") }) {
                let path = dirURL.path
                return path.hasSuffix("/") ? path : path + "/"
            }
            let parent = dirURL.deletingLastPathComponent()
            if parent.path == dirURL.path { // 已到根目录
                break
            }
            dirURL = parent
        }

        // 回退：按常见结构返回上三级作为根 (/ScoreNest/ScoreNest/Preview Content → /ScoreNest)
        let fallback = fileURL
            .deletingLastPathComponent() // Preview Content
            .deletingLastPathComponent() // ScoreNest (app 源码目录)
            .deletingLastPathComponent() // 项目根目录
        let path = fallback.path
        return path.hasSuffix("/") ? path : path + "/"
    }()
    
    /// Provides an array of sample `MusicScore` instances for preview purposes.
    static var sampleScores: [MusicScore] {
        let score1 = MusicScore(title: "Canon in D", pages: [
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/1.png", pageNumber: 1),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/2.png", pageNumber: 2),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/3.png", pageNumber: 3),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/4.png", pageNumber: 4),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/5.png", pageNumber: 5),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/6.png", pageNumber: 6),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/7.png", pageNumber: 7),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/8.png", pageNumber: 8),
        ])
        
        let score2 = MusicScore(title: "River Flows in You", pages: [
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/4.png", pageNumber: 1),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/5.png", pageNumber: 2),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/6.png", pageNumber: 3),
            ScorePage(imageFileName: projectBaseRoot + "ImagesTest/7.png", pageNumber: 4)
        ])
        
        return [score1, score2]
    }
}
