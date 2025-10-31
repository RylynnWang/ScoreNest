import Foundation
import SwiftData

@Model
final class AutoPlayTimeline: Identifiable {
    var id: UUID
    var title: String
    var baseScoreDurationSec: Double
    var defaultWidthRatio: Double
    var createdAt: Date

    // Segments in play order; deleting timeline cascades to its segments.
    @Relationship(deleteRule: .cascade, inverse: \AutoPlaySegment.timeline)
    var segments: [AutoPlaySegment] = []

    // Back-reference to owning score.
    var score: MusicScore?

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        baseScoreDurationSec: Double = 60.0,
        defaultWidthRatio: Double = 1.0,
        createdAt: Date = Date(),
        segments: [AutoPlaySegment] = [],
        score: MusicScore? = nil
    ) {
        self.id = id
        self.title = title
        self.baseScoreDurationSec = baseScoreDurationSec
        self.defaultWidthRatio = defaultWidthRatio
        self.createdAt = createdAt
        self.segments = segments
        self.score = score
    }
}