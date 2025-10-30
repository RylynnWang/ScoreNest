import Foundation
import SwiftData

@Model
final class MusicScore:Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ScorePage.score)
    var pages: [ScorePage] = []
    
    init(id: UUID = UUID(), title: String = "Untitled Score", createdAt: Date = Date(), pages: [ScorePage]) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.pages = pages
    }
}
