import SwiftUI
import SwiftData
import UIKit

struct EditAutoPlayView: View {
    let score: MusicScore
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var baseDuration: Double = 60.0
    @State private var widthRatio: Double = 1.0
    @State private var editingSegment: AutoPlaySegment?
    @State private var editingSpeedFactor: Double = 1.0
    @State private var actionMode: SegmentActionMode? = nil
    @State private var previewSegment: AutoPlaySegment? = nil
    
    var body: some View {
        Form {
            Section(header: Text("Basic Settings")) {
                HStack {
                    Text("Total Duration (seconds)")
                    Spacer()
                    TextField("60", value: $baseDuration, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                HStack {
                    Text("Uniform Width")
                    Spacer()
                    Slider(value: $widthRatio, in: 0.3...1.3, step: 0.01)
                        .frame(maxWidth: 200)
                        .onChange(of: widthRatio) { oldValue, newValue in
                            print("🔧 EditAutoPlayView: Slider changed from \(oldValue) to \(newValue)")
                        }
                    Text(String(format: "%.2f", widthRatio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            
            Section(header: Text("Segments")) {
                if let t = score.autoPlayTimeline {
                    let ordered = t.segments.sorted { $0.order < $1.order }
                    if ordered.isEmpty {
                        Text("No segments")
                            .foregroundStyle(.secondary)
                    } else {
                        if let mode = actionMode, let src = sourceSegment(for: mode) {
                            HStack {
                                Text(instructionText(for: mode, source: src))
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Button("Cancel Selection") { actionMode = nil }
                                    .buttonStyle(.borderless)
                            }
                        }
                        ForEach(ordered) { seg in
                            HStack(spacing: 12) {
                                Text("Segment \(seg.order)")
                                    .font(.headline)
                                Spacer()
                                Text("Page: \(seg.sourcePage?.pageNumber ?? seg.order)")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "Speed ×%.2f", seg.speedFactor))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { handleTapOnSegment(seg) }
                            .contextMenu {
                                Button {
                                    previewSegment = seg
                                } label: {
                                    Label("Preview Segment", systemImage: "eye")
                                }
                                Button {
                                    actionMode = .swap(sourceID: seg.id)
                                } label: {
                                    Label("Swap Segment", systemImage: "arrow.left.arrow.right")
                                }
                                Button {
                                    actionMode = .moveBefore(sourceID: seg.id)
                                } label: {
                                    Label("Reorder", systemImage: "arrow.up.to.line")
                                }
                                Button {
                                    presentSpeedAdjust(for: seg)
                                } label: {
                                    Label("Adjust Speed Factor", systemImage: "speedometer")
                                }
                                Button(role: .destructive) {
                                    deleteSegment(seg)
                                } label: {
                                    Label("Delete Segment", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSegment(seg)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteSegments)
                    }
                } else {
                    Text("Timeline not initialized")
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Add Segment")) {
                if score.autoPlayTimeline != nil {
                    NavigationLink(destination: SelectAutoPlayPageView(score: score)) {
                        Label("Add segment from score page", systemImage: "plus.square.on.square")
                    }
                } else {
                    Text("Timeline not initialized")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Autoplay")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveEdits()
                    dismiss()
                }
                .tint(.blue)
            }
        }
        .onAppear {
            ensureDefaultTimelineIfNeeded()
            initializeStateFromTimeline()
        }
        .sheet(item: $editingSegment) { seg in
            NavigationView {
                Form {
                    Section(header: Text("Speed Adjustment")) {
                        HStack {
                            Text("Speed ×")
                            Spacer()
                            Slider(value: $editingSpeedFactor, in: 0.3...2.0, step: 0.01)
                                .frame(maxWidth: 220)
                            Text(String(format: "%.2f", editingSpeedFactor))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        Text("Tip: >1 faster, <1 slower")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Adjust Speed Factor")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingSegment = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            applySpeedAdjustment(to: seg, factor: editingSpeedFactor)
                            editingSegment = nil
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .sheet(item: $previewSegment) { seg in
            NavigationView {
                SegmentCroppedPreviewView(segment: seg)
                    .navigationTitle("Segment Preview")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { previewSegment = nil }
                        }
                    }
            }
        }
    }

    private func deleteSegments(at offsets: IndexSet) {
        guard let timeline = score.autoPlayTimeline else { return }
        let ordered = timeline.segments.sorted { $0.order < $1.order }
        for index in offsets {
            if index >= 0 && index < ordered.count {
                let segment = ordered[index]
                deleteSegment(segment)
            }
        }
    }

    private func deleteSegment(_ segment: AutoPlaySegment) {
        guard let timeline = score.autoPlayTimeline else { return }
        // Remove from persistent store and relationship
        modelContext.delete(segment)
        timeline.segments.removeAll { $0.id == segment.id }
        if let mode = actionMode, isSource(segment: segment, of: mode) { actionMode = nil }
        // Normalize order to be continuous starting from 1
        let remaining = timeline.segments.sorted { $0.order < $1.order }
        for (idx, seg) in remaining.enumerated() {
            seg.order = idx + 1
        }
        do {
            try modelContext.save()
        } catch {
            print("删除失败: \(error)")
        }
    }

    private func presentSpeedAdjust(for segment: AutoPlaySegment) {
        editingSpeedFactor = segment.speedFactor
        editingSegment = segment
        print("🔧 EditAutoPlayView: Presenting speed adjust for segment order \(segment.order) with current factor \(segment.speedFactor)")
    }

    private func applySpeedAdjustment(to segment: AutoPlaySegment, factor: Double) {
        segment.speedFactor = factor
        do {
            try modelContext.save()
            print("🔧 EditAutoPlayView: Speed adjusted for segment order \(segment.order) to factor \(factor)")
        } catch {
            print("保存失败: \(error)")
        }
    }

    // MARK: - 交换 / 移动
    private enum SegmentActionMode { case swap(sourceID: UUID), moveBefore(sourceID: UUID) }

    private func sourceSegment(for mode: SegmentActionMode) -> AutoPlaySegment? {
        guard let timeline = score.autoPlayTimeline else { return nil }
        switch mode {
        case .swap(let id), .moveBefore(let id):
            return timeline.segments.first(where: { $0.id == id })
        }
    }

    private func isSource(segment: AutoPlaySegment, of mode: SegmentActionMode) -> Bool {
        switch mode {
        case .swap(let id), .moveBefore(let id):
            return segment.id == id
        }
    }

    private func instructionText(for mode: SegmentActionMode, source: AutoPlaySegment) -> String {
        switch mode {
        case .swap:
            return "Select target segment to swap with segment \(source.order)"
        case .moveBefore:
            return "Select target segment to move segment \(source.order) before it"
        }
    }

    private func handleTapOnSegment(_ target: AutoPlaySegment) {
        guard let mode = actionMode, let source = sourceSegment(for: mode) else { return }
        guard source.id != target.id else { return }
        withAnimation {
            switch mode {
            case .swap:
                swapSegments(sourceID: source.id, targetID: target.id)
            case .moveBefore:
                moveSegmentBefore(sourceID: source.id, targetID: target.id)
            }
        }
    }

    private func swapSegments(sourceID: UUID, targetID: UUID) {
        guard let timeline = score.autoPlayTimeline else { return }
        var ordered = timeline.segments.sorted { $0.order < $1.order }
        guard let i = ordered.firstIndex(where: { $0.id == sourceID }),
              let j = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        ordered.swapAt(i, j)
        for (idx, seg) in ordered.enumerated() { seg.order = idx + 1 }
        timeline.segments = ordered
        actionMode = nil
        do {
            try modelContext.save()
            print("🔧 EditAutoPlayView: Swapped segments at indices \(i) and \(j)")
        } catch {
            print("保存失败: \(error)")
        }
    }

    private func moveSegmentBefore(sourceID: UUID, targetID: UUID) {
        guard let timeline = score.autoPlayTimeline else { return }
        var ordered = timeline.segments.sorted { $0.order < $1.order }
        guard let from = ordered.firstIndex(where: { $0.id == sourceID }),
              let toOriginal = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        let moving = ordered.remove(at: from)
        var to = toOriginal
        if from < to { to -= 1 }
        ordered.insert(moving, at: to)
        for (idx, seg) in ordered.enumerated() { seg.order = idx + 1 }
        timeline.segments = ordered
        actionMode = nil
        do {
            try modelContext.save()
            print("🔧 EditAutoPlayView: Moved segment from index \(from) to before index \(toOriginal)")
        } catch {
            print("保存失败: \(error)")
        }
    }

    private func ensureDefaultTimelineIfNeeded() {
        guard score.autoPlayTimeline == nil else { return }
        let timeline = AutoPlayTimeline() // 使用模型默认值：title/时长/宽度
        timeline.score = score
        
        let orderedPages = score.pages.sorted { $0.pageNumber < $1.pageNumber }
        var segments: [AutoPlaySegment] = []
        for p in orderedPages {
            let seg = AutoPlaySegment(
                sourcePage: p,
                cropRectNormalized: RectSpec(x: 0, y: 0, width: 1, height: 1),
                speedFactor: 1.0,
                order: p.pageNumber,
                timeline: timeline
            )
            segments.append(seg)
        }
        timeline.segments = segments
        score.autoPlayTimeline = timeline
        
        modelContext.insert(timeline)
        segments.forEach { modelContext.insert($0) }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save default timeline: \(error)")
        }
    }

    private func initializeStateFromTimeline() {
        guard let t = score.autoPlayTimeline else { return }
        baseDuration = t.baseScoreDurationSec
        widthRatio = t.defaultWidthRatio
        print("🔧 EditAutoPlayView: Initialized widthRatio = \(widthRatio) from timeline.defaultWidthRatio = \(t.defaultWidthRatio)")
    }

    private func saveEdits() {
        guard let t = score.autoPlayTimeline else { return }
        print("🔧 EditAutoPlayView: Saving widthRatio = \(widthRatio) to timeline.defaultWidthRatio")
        t.baseScoreDurationSec = baseDuration
        t.defaultWidthRatio = widthRatio
        do {
            try modelContext.save()
            print("🔧 EditAutoPlayView: Save successful, timeline.defaultWidthRatio = \(t.defaultWidthRatio)")
        } catch {
            print("保存失败: \(error)")
        }
    }
}

// MARK: - 片段裁剪预览视图
private struct SegmentCroppedPreviewView: View {
    let segment: AutoPlaySegment

    var body: some View {
        Group {
            if let page = segment.sourcePage, let uiImage = loadUIImage(named: page.imageFileName) {
                let cropped = crop(image: uiImage, with: segment.cropRectNormalized)
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.03).ignoresSafeArea()
                        Image(uiImage: cropped)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Unable to load segment image")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadUIImage(named: String) -> UIImage? {
        if let img = UIImage(named: named) { return img }
        if FileManager.default.fileExists(atPath: named) { return UIImage(contentsOfFile: named) }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let direct = appSupport.appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: direct.path) { return UIImage(contentsOfFile: direct.path) }
            let nested = appSupport
                .appendingPathComponent("ScoreNestImages", isDirectory: true)
                .appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: nested.path) { return UIImage(contentsOfFile: nested.path) }
        }
        return nil
    }

    private func crop(image: UIImage, with spec: RectSpec?) -> UIImage {
        guard let spec = spec, let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let rect = CGRect(
            x: max(0, CGFloat(spec.x) * w),
            y: max(0, CGFloat(spec.y) * h),
            width: max(0, CGFloat(spec.width) * w),
            height: max(0, CGFloat(spec.height) * h)
        )
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}