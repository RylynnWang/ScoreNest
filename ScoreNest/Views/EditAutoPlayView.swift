import SwiftUI
import SwiftData

struct EditAutoPlayView: View {
    let score: MusicScore
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var baseDuration: Double = 60.0
    @State private var widthRatio: Double = 1.0
    
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
                        }
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