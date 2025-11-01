import SwiftUI
import SwiftData

struct EditAutoPlayView: View {
    let score: MusicScore
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var baseDuration: Double = 60.0
    @State private var widthRatio: Double = 1.0
    @State private var editingSegment: AutoPlaySegment?
    @State private var editingSpeedFactor: Double = 1.0
    @State private var actionMode: SegmentActionMode? = nil
    
    var body: some View {
        Form {
            Section(header: Text("基础设置")) {
                HStack {
                    Text("总时长（秒）")
                    Spacer()
                    TextField("60", value: $baseDuration, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                HStack {
                    Text("统一宽度")
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
            
            Section(header: Text("片段列表")) {
                if let t = score.autoPlayTimeline {
                    let ordered = t.segments.sorted { $0.order < $1.order }
                    if ordered.isEmpty {
                        Text("暂无片段")
                            .foregroundStyle(.secondary)
                    } else {
                        if let mode = actionMode, let src = sourceSegment(for: mode) {
                            HStack {
                                Text(instructionText(for: mode, source: src))
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Button("取消选择") { actionMode = nil }
                                    .buttonStyle(.borderless)
                            }
                        }
                        ForEach(ordered) { seg in
                            HStack(spacing: 12) {
                                Text("段 \(seg.order)")
                                    .font(.headline)
                                Spacer()
                                Text("页: \(seg.sourcePage?.pageNumber ?? seg.order)")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "速度×%.2f", seg.speedFactor))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { handleTapOnSegment(seg) }
                            .contextMenu {
                                Button {
                                    actionMode = .swap(sourceID: seg.id)
                                } label: {
                                    Label("交换片段", systemImage: "arrow.left.arrow.right")
                                }
                                Button {
                                    actionMode = .moveBefore(sourceID: seg.id)
                                } label: {
                                    Label("调整顺序", systemImage: "arrow.up.to.line")
                                }
                                Button {
                                    presentSpeedAdjust(for: seg)
                                } label: {
                                    Label("调整速度修正", systemImage: "speedometer")
                                }
                                Button(role: .destructive) {
                                    deleteSegment(seg)
                                } label: {
                                    Label("删除片段", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSegment(seg)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteSegments)
                    }
                } else {
                    Text("暂无时间线")
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("添加片段")) {
                if score.autoPlayTimeline != nil {
                    NavigationLink(destination: SelectAutoPlayPageView(score: score)) {
                        Label("选择乐谱页添加片段", systemImage: "plus.square.on.square")
                    }
                } else {
                    Text("时间线未初始化")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("编辑自动播放")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
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
                    Section(header: Text("速度修正")) {
                        HStack {
                            Text("速度×")
                            Spacer()
                            Slider(value: $editingSpeedFactor, in: 0.3...2.0, step: 0.01)
                                .frame(maxWidth: 220)
                            Text(String(format: "%.2f", editingSpeedFactor))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        Text("提示：>1 加快，<1 减慢")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("调整速度修正")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { editingSegment = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            applySpeedAdjustment(to: seg, factor: editingSpeedFactor)
                            editingSegment = nil
                        }
                        .tint(.blue)
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
            return "选择目标片段，与第 \(source.order) 段交换"
        case .moveBefore:
            return "选择目标片段，把第 \(source.order) 段放到其前面"
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