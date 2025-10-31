extension MusicScore {
    static let projectBaseRoot = "/Users/wangyujia/Programming/XCodeProject/ScoreNest/"
    
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
