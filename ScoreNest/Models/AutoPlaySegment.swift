import Foundation
import SwiftData

@Model
final class AutoPlaySegment: Identifiable {
    var id: UUID

    // Reference to the original score page; becomes nil if page is deleted.
    @Relationship(deleteRule: .nullify)
    var sourcePage: ScorePage?

    // Optional non-destructive crop rectangle in normalized coordinates.
    var cropRectNormalized: RectSpec?

    // Speed adjustment; >1 faster, <1 slower. Default 1.0
    var speedFactor: Double

    // Play order within the timeline.
    var order: Int

    // Back-reference to owning timeline.
    var timeline: AutoPlayTimeline?

    init(
        id: UUID = UUID(),
        sourcePage: ScorePage? = nil,
        cropRectNormalized: RectSpec? = nil,
        speedFactor: Double = 1.0,
        order: Int,
        timeline: AutoPlayTimeline? = nil
    ) {
        self.id = id
        self.sourcePage = sourcePage
        self.cropRectNormalized = cropRectNormalized
        self.speedFactor = speedFactor
        self.order = order
        self.timeline = timeline
    }
}