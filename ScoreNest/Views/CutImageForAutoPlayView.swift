import SwiftUI
import SwiftData
import UIKit

struct CutImageForAutoPlayView: View {
    let page: ScorePage
    let timeline: AutoPlayTimeline

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var cropSpec: RectSpec = RectSpec(x: 0, y: 0, width: 1, height: 1)
    @State private var speedFactor: Double = 1.0

    private let minSizeNormalized: Double = 0.05

    var body: some View {
        VStack(spacing: 0) {
            // Top control section: speed and current crop spec
            Form {
                Section(header: Text("速度修正")) {
                    HStack {
                        Slider(value: $speedFactor, in: 0.5...2.0, step: 0.01)
                        Text(String(format: "%.2f", speedFactor))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text("裁剪矩形")
                        Spacer()
                        Text(String(format: "x=%.2f y=%.2f w=%.2f h=%.2f", cropSpec.x, cropSpec.y, cropSpec.width, cropSpec.height))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            Divider()

            // Full-screen cropping area below, image always fully visible (aspect fit)
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.03)
                        .ignoresSafeArea()

                    if let uiImage = loadUIImage(named: page.imageFileName) {
                        let fitted = aspectFitSize(for: uiImage.size, in: geo.size)

                        ZStack(alignment: .topLeading) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: fitted.width, height: fitted.height)

                            CropOverlay(cropSpec: $cropSpec, imageDisplaySize: fitted, minSizeNormalized: minSizeNormalized)
                                .frame(width: fitted.width, height: fitted.height)
                        }
                        // Center the fitted image within the available space
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("无法加载图片")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("裁剪片段")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("确认") {
                    saveSegment()
                    dismiss()
                }
                .tint(.blue)
            }
        }
    }

    private func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let imgAspect = imageSize.width / imageSize.height
        let containerAspect = max(0.0001, containerSize.width / containerSize.height)
        if imgAspect > containerAspect {
            let w = containerSize.width
            let h = w / imgAspect
            return CGSize(width: w, height: h)
        } else {
            let h = containerSize.height
            let w = h * imgAspect
            return CGSize(width: w, height: h)
        }
    }

    private func saveSegment() {
        // Clamp normalized values and enforce minimal size
        var c = cropSpec
        c.width = max(minSizeNormalized, c.width)
        c.height = max(minSizeNormalized, c.height)
        c.x = max(0.0, min(1.0 - c.width, c.x))
        c.y = max(0.0, min(1.0 - c.height, c.y))

        let nextOrder = (timeline.segments.map { $0.order }.max() ?? 0) + 1
        let seg = AutoPlaySegment(
            sourcePage: page,
            cropRectNormalized: c,
            speedFactor: speedFactor,
            order: nextOrder,
            timeline: timeline
        )
        timeline.segments.append(seg)
        modelContext.insert(seg)
        do {
            try modelContext.save()
            print("🔧 CutImageForAutoPlayView: Added segment order=\(nextOrder) speed=\(speedFactor) crop=\(c)")
        } catch {
            print("保存裁剪片段失败: \(error)")
        }
    }

    private func loadUIImage(named: String) -> UIImage? {
        if let img = UIImage(named: named) { return img }
        if FileManager.default.fileExists(atPath: named) {
            return UIImage(contentsOfFile: named)
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let direct = appSupport.appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: direct.path) {
                return UIImage(contentsOfFile: direct.path)
            }
            let nested = appSupport
                .appendingPathComponent("ScoreNestImages", isDirectory: true)
                .appendingPathComponent(named)
            if FileManager.default.fileExists(atPath: nested.path) {
                return UIImage(contentsOfFile: nested.path)
            }
        }
        return nil
    }
}

private struct CropOverlay: View {
    @Binding var cropSpec: RectSpec
    let imageDisplaySize: CGSize
    let minSizeNormalized: Double

    // 记录拖拽起点的矩形，用于稳定增量计算
    @State private var startRect: RectSpec? = nil

    var body: some View {
        let rectX = CGFloat(cropSpec.x) * imageDisplaySize.width
        let rectY = CGFloat(cropSpec.y) * imageDisplaySize.height
        let rectW = CGFloat(cropSpec.width) * imageDisplaySize.width
        let rectH = CGFloat(cropSpec.height) * imageDisplaySize.height
        let handleRadiusBR: CGFloat = 11 // bottom-right handle radius (22pt diameter)
        let handleRadiusTL: CGFloat = 9  // top-left handle radius (18pt diameter)

        ZStack(alignment: .topLeading) {
            // Stroke rectangle representing crop area
            Rectangle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: rectW, height: rectH)
                .position(x: rectX + rectW / 2, y: rectY + rectH / 2)
                .gesture(moveGesture())
                
            // Bottom-right resize handle
            Circle()
                .fill(Color.blue)
                .frame(width: 22, height: 22)
                .position(x: rectX + rectW, y: rectY + rectH)
                .gesture(resizeBRGesture())
                
            // Optional: top-left handle for resizing from origin
            Circle()
                .fill(Color.blue)
                .frame(width: 18, height: 18)
                .position(x: rectX, y: rectY)
                .gesture(resizeTLGesture())
        }
    }

    // Drag whole rectangle
    private func moveGesture() -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if startRect == nil { startRect = cropSpec }
                guard let start = startRect else { return }
                let dxNorm = Double(value.translation.width / imageDisplaySize.width)
                let dyNorm = Double(value.translation.height / imageDisplaySize.height)
                let newX = max(0.0, min(1.0 - start.width, start.x + dxNorm))
                let newY = max(0.0, min(1.0 - start.height, start.y + dyNorm))
                cropSpec.x = newX
                cropSpec.y = newY
            }
            .onEnded { _ in
                startRect = nil
            }
    }

    // Resize from bottom-right corner
    private func resizeBRGesture() -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if startRect == nil { startRect = cropSpec }
                guard let start = startRect else { return }
                let dwNorm = Double(value.translation.width / imageDisplaySize.width)
                let dhNorm = Double(value.translation.height / imageDisplaySize.height)
                var newW = start.width + dwNorm
                var newH = start.height + dhNorm
                newW = max(minSizeNormalized, min(1.0 - start.x, newW))
                newH = max(minSizeNormalized, min(1.0 - start.y, newH))
                cropSpec.width = newW
                cropSpec.height = newH
            }
            .onEnded { _ in
                startRect = nil
            }
    }

    // Resize from top-left corner (affects origin and size)
    private func resizeTLGesture() -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if startRect == nil { startRect = cropSpec }
                guard let start = startRect else { return }
                let dxNorm = Double(value.translation.width / imageDisplaySize.width)
                let dyNorm = Double(value.translation.height / imageDisplaySize.height)

                // First clamp the new origin so that we always keep at least minSizeNormalized
                // and never go beyond the image bounds
                var newX = start.x + dxNorm
                var newY = start.y + dyNorm
                newX = max(0.0, min(start.x + start.width - minSizeNormalized, newX))
                newY = max(0.0, min(start.y + start.height - minSizeNormalized, newY))

                // Compute size from clamped origin, then clamp size to image bounds
                var newW = start.width - (newX - start.x)
                var newH = start.height - (newY - start.y)
                newW = max(minSizeNormalized, min(1.0 - newX, newW))
                newH = max(minSizeNormalized, min(1.0 - newY, newH))

                cropSpec.x = newX
                cropSpec.y = newY
                cropSpec.width = newW
                cropSpec.height = newH
            }
            .onEnded { _ in
                startRect = nil
            }
    }
}
