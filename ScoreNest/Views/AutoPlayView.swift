import SwiftUI
import SwiftData
import UIKit

struct AutoPlayView: View {
    let timeline: AutoPlayTimeline

    var body: some View {
        AutoPlayScrollView(timeline: timeline)
            .navigationTitle("自动播放")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// A specialized UIScrollView host that auto-scrolls vertically based on the timeline.
// - No user zoom or pan
// - Uses timeline.defaultWidthRatio to determine content width
// - Simple mode (non-normalized): base speed = totalPixels / baseDuration
struct AutoPlayScrollView: UIViewRepresentable {
    let timeline: AutoPlayTimeline

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        print("🔧 AutoPlayView: Creating UIScrollView with defaultWidthRatio = \(timeline.defaultWidthRatio)")
        
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .systemBackground
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false
        scrollView.bounces = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        print("🔧 AutoPlayView: contentView pinned to contentLayoutGuide; width driven by stack width")
        
        // Pin contentView to scrollView content layout guide on all sides
        // Width will be driven by inner stack's explicit width constraint
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        // stack fills contentView completely
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        // Defer configuration to next runloop so SwiftUI can size the scrollView
        DispatchQueue.main.async {
            context.coordinator.configure(with: timeline, scrollView: scrollView, stackView: stack)
        }
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // In this first version, timeline is considered immutable during playback.
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.stop()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var stackView: UIStackView?
        var stackWidthConstraint: NSLayoutConstraint?
        var displayLink: CADisplayLink?
        var lastTimestamp: CFTimeInterval?

        // Playback metrics
        var endOffsets: [CGFloat] = []
        var speeds: [CGFloat] = []
        var currentIndex: Int = 0

        func configure(with timeline: AutoPlayTimeline, scrollView: UIScrollView, stackView: UIStackView) {
            print("🔧 Coordinator: Starting configure with defaultWidthRatio = \(timeline.defaultWidthRatio)")
            
            self.scrollView = scrollView
            self.stackView = stackView

            // Build segment views
            let segments = timeline.segments.sorted { $0.order < $1.order }
            print("🔧 Coordinator: Processing \(segments.count) segments")
            
            for seg in segments {
                guard let src = seg.sourcePage, let image = loadUIImage(named: src.imageFileName) else { continue }
                let cropped = crop(image: image, with: seg.cropRectNormalized)
                let imageView = UIImageView(image: cropped)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.contentMode = .scaleAspectFit

                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(imageView)

                stackView.addArrangedSubview(container)

                // Image fills container width; height follows aspect ratio
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    imageView.topAnchor.constraint(equalTo: container.topAnchor),
                    imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    container.widthAnchor.constraint(equalTo: stackView.widthAnchor),
                    container.heightAnchor.constraint(equalTo: container.widthAnchor, multiplier: cropped.size.height / cropped.size.width)
                ])
            }

            // First layout to obtain scrollView bounds width
            scrollView.layoutIfNeeded()
            let viewportWidth = scrollView.bounds.width
            let targetContentWidth = viewportWidth * CGFloat(timeline.defaultWidthRatio)
            print("🔧 Coordinator: viewportWidth = \(viewportWidth), targetContentWidth = \(targetContentWidth)")

            // Drive content width by setting explicit stack width constraint
            let widthConstraint = stackView.widthAnchor.constraint(equalToConstant: targetContentWidth)
            widthConstraint.isActive = true
            self.stackWidthConstraint = widthConstraint
            
            // Relayout to apply width and compute content size
            scrollView.layoutIfNeeded()
            
            print("🔧 Coordinator: After layoutIfNeeded - scrollView.bounds = \(scrollView.bounds)")
            print("🔧 Coordinator: After layoutIfNeeded - scrollView.contentSize = \(scrollView.contentSize)")
            print("🔧 Coordinator: After layoutIfNeeded - stackView.bounds = \(stackView.bounds)")
            
            updateHorizontalInsets()

            // Compute end offsets for each segment (bottom Y of arranged subview)
            var cumulative: CGFloat = 0
            var computedEnd: [CGFloat] = []
            for v in stackView.arrangedSubviews {
                cumulative += v.bounds.height + stackView.spacing
                computedEnd.append(cumulative)
            }
            if !computedEnd.isEmpty {
                // account for top/bottom padding (16 + 16) already included by constraints; spacing accounted above
                // The content is inside contentLayoutGuide, so we can directly use cumulative values
                self.endOffsets = computedEnd
            } else {
                self.endOffsets = []
            }

            // Simple mode speed calculation
            let totalPixels: CGFloat = endOffsets.last ?? 0
            let base = totalPixels > 0 ? CGFloat(totalPixels) / CGFloat(timeline.baseScoreDurationSec) : 0
            self.speeds = timeline.segments.sorted { $0.order < $1.order }.map { CGFloat(base) * CGFloat($0.speedFactor) }
            self.currentIndex = 0

            start()
        }

        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            // Update width constraint on bounds changes (e.g., rotation)
            guard let widthConstraint = stackWidthConstraint else { return }
            let viewportWidth = scrollView.bounds.width
            let timelineRatio: CGFloat
            if let sv = self.stackView, let parentView = sv.superview, parentView is UIView {
                // Use last known ratio from constraint
                timelineRatio = widthConstraint.constant / max(viewportWidth, 1)
            } else {
                timelineRatio = 1.0
            }
            widthConstraint.constant = viewportWidth * timelineRatio
            scrollView.layoutIfNeeded()
            updateHorizontalInsets()
            print("🔧 scrollViewDidLayoutSubviews: viewportWidth = \(viewportWidth), new stackWidth = \(widthConstraint.constant), contentSize = \(scrollView.contentSize)")
        }

        func start() {
            stop()
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTimestamp = nil
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let scrollView else { return }
            guard !endOffsets.isEmpty, !speeds.isEmpty else { return }

            let dt: CFTimeInterval
            if let last = lastTimestamp { dt = link.timestamp - last } else { dt = link.duration }
            lastTimestamp = link.timestamp

            let speed = speeds[min(currentIndex, speeds.count - 1)]
            var newY = scrollView.contentOffset.y + CGFloat(dt) * speed
            let segmentEnd = endOffsets[min(currentIndex, endOffsets.count - 1)]

            if newY >= segmentEnd {
                newY = segmentEnd
                currentIndex += 1
                if currentIndex >= endOffsets.count {
                    // Reached end; stop
                    stop()
                }
            }

            // Preserve current horizontal offset to avoid breaking centering
            let currentX = scrollView.contentOffset.x
            scrollView.setContentOffset(CGPoint(x: currentX, y: newY), animated: false)
        }

        // MARK: - Helpers
        private func updateHorizontalInsets() {
            guard let scrollView else { return }
            let boundsWidth = scrollView.bounds.width
            let contentWidth = scrollView.contentSize.width

            // Always center horizontally: narrow content via inset + negative offset,
            // wide content via zero inset + midpoint positive offset.
            let inset = max(0, (boundsWidth - contentWidth) / 2)
            var targetX: CGFloat
            if inset > 0 {
                // Content narrower than viewport: use symmetric inset and negative offset
                scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
                targetX = -inset
            } else {
                // Content wider than viewport: no inset, scroll to mid-point
                scrollView.contentInset = .zero
                targetX = max(0, (contentWidth - boundsWidth) / 2)
            }

            print("🔧 updateHorizontalInsets: boundsWidth = \(boundsWidth), contentWidth = \(contentWidth), inset = \(inset), centerX = \(targetX)")

            if abs(scrollView.contentOffset.x - targetX) > 0.5 {
                scrollView.setContentOffset(CGPoint(x: targetX, y: scrollView.contentOffset.y), animated: false)
            }
            print("🔧 updateHorizontalInsets: applied contentInset = \(scrollView.contentInset), offsetX = \(scrollView.contentOffset.x)")
        }
        private func loadUIImage(named: String) -> UIImage? {
            if let img = UIImage(named: named) { return img }
            if FileManager.default.fileExists(atPath: named) { return UIImage(contentsOfFile: named) }
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let direct = appSupport.appendingPathComponent(named)
                if FileManager.default.fileExists(atPath: direct.path) { return UIImage(contentsOfFile: direct.path) }
                let nested = appSupport.appendingPathComponent("ScoreNestImages", isDirectory: true).appendingPathComponent(named)
                if FileManager.default.fileExists(atPath: nested.path) { return UIImage(contentsOfFile: nested.path) }
            }
            return nil
        }

        private func crop(image: UIImage, with spec: RectSpec?) -> UIImage {
            guard let spec = spec, let cg = image.cgImage else { return image }
            let w = CGFloat(cg.width)
            let h = CGFloat(cg.height)
            let rect = CGRect(x: max(0, CGFloat(spec.x) * w),
                              y: max(0, CGFloat(spec.y) * h),
                              width: max(0, CGFloat(spec.width) * w),
                              height: max(0, CGFloat(spec.height) * h))
            guard let cropped = cg.cropping(to: rect) else { return image }
            return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        }
    }
}