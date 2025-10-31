import SwiftUI
import UIKit

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 3.0
    let content: Content

    init(minScale: CGFloat = 1.0, maxScale: CGFloat = 3.0, @ViewBuilder content: () -> Content) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(minScale: minScale, maxScale: maxScale)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale
        scrollView.zoomScale = minScale
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.hostingController = hostingController
        context.coordinator.contentView = hostingController.view
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
        context.coordinator.centerContent()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var contentView: UIView?
        var hostingController: UIHostingController<Content>?
        private let configuredMinScale: CGFloat
        private let configuredMaxScale: CGFloat

        init(minScale: CGFloat, maxScale: CGFloat) {
            self.configuredMinScale = minScale
            self.configuredMaxScale = maxScale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            contentView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
        }

        func centerContent() {
            guard let scrollView else { return }
            let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let contentView else { return }
            let targetScale: CGFloat = scrollView.zoomScale == scrollView.minimumZoomScale
                ? min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2)
                : scrollView.minimumZoomScale

            let location = gesture.location(in: contentView)
            let size = CGSize(width: scrollView.bounds.size.width / targetScale,
                              height: scrollView.bounds.size.height / targetScale)
            let origin = CGPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
            let rect = CGRect(origin: origin, size: size)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}