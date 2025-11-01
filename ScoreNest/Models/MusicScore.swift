import Foundation
import SwiftData

@Model
final class MusicScore:Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ScorePage.score)
    var pages: [ScorePage] = []

    // Optional AutoPlay timeline; deleting the score cascades to its timeline.
    @Relationship(deleteRule: .cascade, inverse: \AutoPlayTimeline.score)
    var autoPlayTimeline: AutoPlayTimeline? = nil
    
    init(id: UUID = UUID(), title: String = "Untitled Score", createdAt: Date = Date(), pages: [ScorePage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.pages = pages
    }
}
