import SwiftUI
import UIKit

struct ZoomableImage: UIViewRepresentable {
    let uiImage: UIImage
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 4.0

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.clipsToBounds = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale
        scrollView.zoomScale = minScale
        scrollView.isScrollEnabled = false // 初始不与外层滚动冲突

        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        // 根据容器尺寸计算最小缩放以适配
        DispatchQueue.main.async {
            context.coordinator.updateScalesToFit()
        }
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = uiImage
        context.coordinator.updateScalesToFit()
        context.coordinator.centerContent()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(minScale: minScale, maxScale: maxScale)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private let configuredMinScale: CGFloat
        private let configuredMaxScale: CGFloat

        init(minScale: CGFloat, maxScale: CGFloat) {
            self.configuredMinScale = minScale
            self.configuredMaxScale = maxScale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
            updateScrollEnable()
        }

        func centerContent() {
            guard let scrollView else { return }
            let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
        }

        func updateScalesToFit() {
            guard let scrollView, let image = imageView?.image else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds.height > 0, image.size.width > 0, image.size.height > 0 else { return }

            let scaleX = bounds.width / image.size.width
            let scaleY = bounds.height / image.size.height
            let fitMinScale = min(scaleX, scaleY)

            // 保持配置的倍数比例（如 1→4 保持 4x）
            let ratio = configuredMaxScale / max(configuredMinScale, 0.0001)
            scrollView.minimumZoomScale = max(fitMinScale, 0.1)
            scrollView.maximumZoomScale = max(scrollView.minimumZoomScale * ratio, scrollView.minimumZoomScale)

            // 初始或图片更新时，设置为最小缩放以完全适配
            if abs(scrollView.zoomScale - configuredMinScale) < 0.001 || scrollView.zoomScale < scrollView.minimumZoomScale {
                scrollView.zoomScale = scrollView.minimumZoomScale
            }

            updateScrollEnable()
        }

        private func updateScrollEnable() {
            guard let scrollView else { return }
            scrollView.isScrollEnabled = scrollView.zoomScale > scrollView.minimumZoomScale + 0.001
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            let targetScale: CGFloat = scrollView.zoomScale == scrollView.minimumZoomScale
                ? min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2)
                : scrollView.minimumZoomScale

            let location = gesture.location(in: imageView)
            let size = CGSize(width: scrollView.bounds.size.width / targetScale,
                              height: scrollView.bounds.size.height / targetScale)
            let origin = CGPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
            let rect = CGRect(origin: origin, size: size)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}