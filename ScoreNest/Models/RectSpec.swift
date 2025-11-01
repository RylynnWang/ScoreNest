import Foundation

/// Normalized rectangle specification used for non-destructive crop.
/// All values are in [0, 1], relative to the source image/page.
struct RectSpec: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double = 0.0, y: Double = 0.0, width: Double = 1.0, height: Double = 1.0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Returns true if all components are within [0, 1].
    var isNormalized: Bool {
        return (0.0...1.0).contains(x)
            && (0.0...1.0).contains(y)
            && (0.0...1.0).contains(width)
            && (0.0...1.0).contains(height)
    }
}