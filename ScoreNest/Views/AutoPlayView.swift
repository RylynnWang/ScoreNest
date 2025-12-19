import SwiftUI
import SwiftData
import UIKit

struct AutoPlayView: View {
    let timeline: AutoPlayTimeline
    @State private var isPlaying: Bool = false

    var body: some View {
        AutoPlayScrollView(timeline: timeline, isPlaying: $isPlaying)
            .navigationTitle("Autoplay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isPlaying.toggle() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                }
            }
    }
}

// A specialized UIScrollView host that auto-scrolls vertically based on the timeline.
// - No user zoom or pan
// - Uses timeline.defaultWidthRatio to determine content width
// - Simple mode (non-normalized): base speed = totalPixels / baseDuration
struct AutoPlayScrollView: UIViewRepresentable {
    let timeline: AutoPlayTimeline
    var isPlaying: Binding<Bool>

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .systemBackground
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = context.coordinator

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

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
            context.coordinator.isPlayingBinding = isPlaying
            context.coordinator.configure(with: timeline, scrollView: scrollView, stackView: stack)
            context.coordinator.setPlaying(isPlaying.wrappedValue)
        }
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Respond to play/pause toggles
        context.coordinator.setPlaying(isPlaying.wrappedValue)
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
        var startTimestamp: CFTimeInterval?
        var isPlaying: Bool = false
        var isPlayingBinding: Binding<Bool>?
        var pendingResumeY: CGFloat?

        // Playback metrics: timeline-driven approach
        var segmentEndOffsets: [CGFloat] = []  // Y offset where each segment ends
        var segmentEndTimes: [CFTimeInterval] = []  // Time when each segment should end
        var totalDuration: CFTimeInterval = 0
        var currentSegmentIndex: Int = 0

        func configure(with timeline: AutoPlayTimeline, scrollView: UIScrollView, stackView: UIStackView) {
            self.scrollView = scrollView
            self.stackView = stackView

            // Build segment views
            let segments = timeline.segments.sorted { $0.order < $1.order }
            
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

            // Drive content width by setting explicit stack width constraint
            let widthConstraint = stackView.widthAnchor.constraint(equalToConstant: targetContentWidth)
            widthConstraint.isActive = true
            self.stackWidthConstraint = widthConstraint
            
            // Relayout to apply width and compute content size
            scrollView.layoutIfNeeded()
            
            updateHorizontalInsets()
            
            // 📊 DEBUG: Log viewport and content dimensions
            let viewportHeight = scrollView.bounds.height
            let contentHeight = scrollView.contentSize.height
            print("📊 [SETUP] Viewport: \(viewportWidth) × \(viewportHeight)")
            print("📊 [SETUP] Content size: \(scrollView.contentSize.width) × \(contentHeight)")
            print("📊 [SETUP] WidthRatio: \(timeline.defaultWidthRatio)")
            print("📊 [SETUP] Segment count: \(segments.count)")

            // Compute segment distances and end offsets
            let maxScrollableY = max(0, scrollView.contentSize.height - viewportHeight)
            var endOffsets: [CGFloat] = []
            var distances: [CGFloat] = []
            var previousEnd: CGFloat = 0
            
            for (idx, v) in stackView.arrangedSubviews.enumerated() {
                let bottomY = stackView.frame.minY + v.frame.maxY
                let endY: CGFloat
                
                if idx == stackView.arrangedSubviews.count - 1 {
                    // Last segment must reach the absolute bottom
                    endY = maxScrollableY
                } else {
                    endY = max(0, min(bottomY - viewportHeight, maxScrollableY))
                }
                
                endOffsets.append(endY)
                let distance = endY - previousEnd
                distances.append(distance)
                previousEnd = endY
                
                print("📊 [SEGMENT-\(idx)] Height: \(v.frame.height), EndOffset: \(endY), Distance: \(distance)")
            }

            // Calculate time allocation using weighted distance method
            let baseDuration = timeline.baseScoreDurationSec
            let sortedSegments = timeline.segments.sorted { $0.order < $1.order }
            
            // Step 1: Calculate total weighted distance
            var totalWeightedDistance: CGFloat = 0
            for (idx, seg) in sortedSegments.enumerated() {
                guard idx < distances.count else { continue }
                let weightedDist = distances[idx] / CGFloat(seg.speedFactor)
                totalWeightedDistance += weightedDist
            }
            
            // Step 2: Allocate time to each segment based on weighted distance
            var segmentDurations: [CFTimeInterval] = []
            var cumulativeTimes: [CFTimeInterval] = []
            var accumulatedTime: CFTimeInterval = 0
            
            for (idx, seg) in sortedSegments.enumerated() {
                guard idx < distances.count else { continue }
                let weightedDist = distances[idx] / CGFloat(seg.speedFactor)
                let segmentDuration = (Double(weightedDist) / Double(totalWeightedDistance)) * baseDuration
                segmentDurations.append(segmentDuration)
                accumulatedTime += segmentDuration
                cumulativeTimes.append(accumulatedTime)
                
                let speed = distances[idx] / CGFloat(segmentDuration)
                print("📊 [SEGMENT-\(idx)] Distance: \(String(format: "%.1f", distances[idx])), Duration: \(String(format: "%.2f", segmentDuration))s, Speed: \(String(format: "%.1f", speed)) px/s")
            }
            
            self.segmentEndOffsets = endOffsets
            self.segmentEndTimes = cumulativeTimes
            self.totalDuration = baseDuration
            self.currentSegmentIndex = 0
            
            print("📊 [CALC] Total scrollable distance: \(maxScrollableY)")
            print("📊 [CALC] Total duration: \(baseDuration)s")
            print("📊 [CALC] Total weighted distance: \(totalWeightedDistance)")

            // Start/stop will be controlled by setPlaying() invoked after configure
        }

        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            // Update width constraint on bounds changes (e.g., rotation)
            guard let widthConstraint = stackWidthConstraint else { return }
            let viewportWidth = scrollView.bounds.width
            let timelineRatio: CGFloat
            if self.stackView?.superview != nil {
                // Use last known ratio from constraint
                timelineRatio = widthConstraint.constant / max(viewportWidth, 1)
            } else {
                timelineRatio = 1.0
            }
            widthConstraint.constant = viewportWidth * timelineRatio
            scrollView.layoutIfNeeded()
            updateHorizontalInsets()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateCurrentIndex(forY: scrollView.contentOffset.y)
        }

        func start() {
            stop()
            pendingResumeY = scrollView?.contentOffset.y
            print("⏱️ [PLAYBACK] ▶️ Starting playback from y=\(pendingResumeY ?? 0)")
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTimestamp = nil
            startTimestamp = nil
        }

        func stop() {
            if displayLink != nil {
                print("⏱️ [PLAYBACK] ⏸️ Stopping playback at y=\(scrollView?.contentOffset.y ?? 0)")
            }
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
            startTimestamp = nil
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let scrollView else { return }
            guard !segmentEndOffsets.isEmpty, !segmentEndTimes.isEmpty else { return }

            // Do not fight user gestures
            if scrollView.isDragging || scrollView.isDecelerating {
                pendingResumeY = scrollView.contentOffset.y
                lastTimestamp = link.timestamp
                startTimestamp = nil
                return
            }

            // Skip first frame to get accurate timestamp baseline
            if startTimestamp == nil {
                lastTimestamp = link.timestamp
                let resumeY = pendingResumeY ?? scrollView.contentOffset.y
                let resumeElapsed = playbackElapsed(forY: resumeY)
                startTimestamp = link.timestamp - resumeElapsed
                pendingResumeY = nil
                print("⏱️ [TICK] Sync baseline: y=\(String(format: "%.1f", resumeY)), elapsed=\(String(format: "%.2f", resumeElapsed))s")
                return
            }

            let elapsed = link.timestamp - startTimestamp!
            lastTimestamp = link.timestamp

            // Find which segment we should be in based on elapsed time
            var targetSegment = 0
            for (idx, endTime) in segmentEndTimes.enumerated() {
                if elapsed < endTime {
                    targetSegment = idx
                    break
                }
                targetSegment = idx + 1
            }
            
            // Check if playback is complete
            if targetSegment >= segmentEndOffsets.count {
                let finalY = segmentEndOffsets.last ?? 0
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: finalY), animated: false)
                print("⏱️ [TICK] ✅ Playback finished: total time = \(String(format: "%.2f", elapsed))s")
                stop()
                isPlayingBinding?.wrappedValue = false
                return
            }
            
            // Calculate target Y position based on time progress within current segment
            let segmentStartTime: CFTimeInterval = targetSegment > 0 ? segmentEndTimes[targetSegment - 1] : 0
            let segmentEndTime = segmentEndTimes[targetSegment]
            let segmentStartY: CGFloat = targetSegment > 0 ? segmentEndOffsets[targetSegment - 1] : 0
            let segmentEndY = segmentEndOffsets[targetSegment]
            
            let timeInSegment = elapsed - segmentStartTime
            let segmentDuration = segmentEndTime - segmentStartTime
            let progress = min(1.0, timeInSegment / segmentDuration)
            
            let targetY = segmentStartY + (segmentEndY - segmentStartY) * CGFloat(progress)

            // Update segment index for logging
            if targetSegment != currentSegmentIndex {
                print("⏱️ [TICK] Segment \(currentSegmentIndex) completed at y=\(segmentEndOffsets[currentSegmentIndex]), t=\(String(format: "%.2f", elapsed))s")
                currentSegmentIndex = targetSegment
            }

            // Log progress every 5 seconds
            let elapsedInt = Int(elapsed)
            if elapsedInt % 5 == 0 && abs(elapsed - Double(elapsedInt)) < 0.1 {
                print("⏱️ [PROGRESS] t=\(String(format: "%.1f", elapsed))s, y=\(String(format: "%.1f", targetY)), seg=\(targetSegment), progress=\(String(format: "%.1f%%", progress * 100))")
            }

            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: false)
        }

        func setPlaying(_ playing: Bool) {
            if playing == isPlaying { return }
            isPlaying = playing
            if playing { start() } else { stop() }
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

            if abs(scrollView.contentOffset.x - targetX) > 0.5 {
                scrollView.setContentOffset(CGPoint(x: targetX, y: scrollView.contentOffset.y), animated: false)
            }
        }

        private func updateCurrentIndex(forY y: CGFloat) {
            guard !segmentEndOffsets.isEmpty else { currentSegmentIndex = 0; return }
            var idx = 0
            while idx < segmentEndOffsets.count && y >= segmentEndOffsets[idx] { idx += 1 }
            currentSegmentIndex = min(idx, segmentEndOffsets.count - 1)
        }
        
        private func playbackElapsed(forY y: CGFloat) -> CFTimeInterval {
            guard !segmentEndOffsets.isEmpty, !segmentEndTimes.isEmpty else { return 0 }
            
            let maxY = segmentEndOffsets.last ?? 0
            let clampedY = min(max(y, 0), maxY)
            
            var idx = 0
            while idx < segmentEndOffsets.count && clampedY > segmentEndOffsets[idx] { idx += 1 }
            idx = min(max(idx, 0), min(segmentEndOffsets.count - 1, segmentEndTimes.count - 1))
            
            let segmentStartY: CGFloat = idx > 0 ? segmentEndOffsets[idx - 1] : 0
            let segmentEndY: CGFloat = segmentEndOffsets[idx]
            
            let segmentStartTime: CFTimeInterval = idx > 0 ? segmentEndTimes[idx - 1] : 0
            let segmentEndTime: CFTimeInterval = segmentEndTimes[idx]
            
            let denom = segmentEndY - segmentStartY
            if abs(denom) < 0.0001 { return segmentStartTime }
            
            let progress = min(1, max(0, (clampedY - segmentStartY) / denom))
            return segmentStartTime + Double(progress) * (segmentEndTime - segmentStartTime)
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
