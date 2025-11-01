import Foundation
import SwiftData

@Model
final class ScorePage:Identifiable {
    var id: UUID
    var imageFileName: String
    var pageNumber: Int  
    var note: String?    
    
    var score: MusicScore?
    
    init(id: UUID = UUID(), imageFileName: String = "Unnamed", pageNumber: Int = 1, note: String? = nil, score: MusicScore? = nil) {
        self.id = id
        self.imageFileName = imageFileName
        self.pageNumber = pageNumber
        self.note = note
        self.score = score
    }
}
