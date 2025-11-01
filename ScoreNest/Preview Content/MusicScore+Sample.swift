import Foundation

extension MusicScore {
    // Dynamically compute the project root: walk up from the current source file to find a directory containing an .xcodeproj
    static let projectBaseRoot: String = {
        let fileURL = URL(fileURLWithPath: #file)
        var dirURL = fileURL.deletingLastPathComponent() // .../ScoreNest/Preview Content
        let fm = FileManager.default

        // Walk upward until reaching the root or encountering any .xcodeproj directory
        for _ in 0..<24 { // Reasonable upper bound to avoid infinite loops from extreme paths
            let items = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
            if items.contains(where: { $0.hasSuffix(".xcodeproj") }) {
                let path = dirURL.path
                return path.hasSuffix("/") ? path : path + "/"
            }
            let parent = dirURL.deletingLastPathComponent()
            if parent.path == dirURL.path { // Reached the root directory
                break
            }
            dirURL = parent
        }

        // Fallback: ascend three levels as the root following common structure (/ScoreNest/ScoreNest/Preview Content → /ScoreNest)
        let fallback = fileURL
            .deletingLastPathComponent() // Preview Content
            .deletingLastPathComponent() // ScoreNest (app source code directory)
            .deletingLastPathComponent() // Project root directory
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
