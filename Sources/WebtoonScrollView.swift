import SwiftUI
import Kingfisher
import UIKit

/// 竖向条漫阅读：UIKit UIScrollView + Kingfisher，精准记录阅读进度，单击切换工具栏。
struct WebtoonScrollView: UIViewControllerRepresentable {
    let urls: [URL]
    let initialIndex: Int
    var onPageChange: (Int) -> Void
    var onTap: () -> Void

    func makeUIViewController(context: Context) -> WebtoonHost {
        let host = WebtoonHost()
        host.urls = urls
        host.initialIndex = initialIndex
        host.onPageChange = onPageChange
        host.onTap = onTap
        host.load()
        return host
    }

    func updateUIViewController(_ host: WebtoonHost, context: Context) {
        if host.urls.map({ $0.absoluteString }) != urls.map({ $0.absoluteString }) {
            host.urls = urls
            host.initialIndex = initialIndex
            host.load()
        }
    }
}

final class WebtoonHost: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var urls: [URL] = []
    var initialIndex: Int = 0
    var onPageChange: ((Int) -> Void) = { _ in }
    var onTap: () -> Void = {}

    private var scrollView: UIScrollView!
    private var stack: UIStackView!
    private var imageViews: [UIImageView] = []
    private var heightConstraints: [NSLayoutConstraint] = []
    private var heights: [CGFloat] = []
    private var lastReported = -1

    private var contentWidth: CGFloat { UIScreen.main.bounds.width }

    func load() {
        view.backgroundColor = .black
        view.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        heightConstraints.removeAll()
        heights = Array(repeating: contentWidth * 1.4, count: urls.count)
        lastReported = -1

        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let modifier = GHeaderModifier(headers: SourceConfig.current.headers)
        let options: KingfisherOptionsInfo = [.requestModifier(modifier), .cacheOriginalImage]

        for (i, url) in urls.enumerated() {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.backgroundColor = .black
            iv.clipsToBounds = true
            iv.translatesAutoresizingMaskIntoConstraints = false
            let hc = iv.heightAnchor.constraint(equalToConstant: heights[i])
            hc.isActive = true
            stack.addArrangedSubview(iv)
            imageViews.append(iv)
            heightConstraints.append(hc)

            KingfisherManager.shared.retrieveImage(with: url, options: options) { [weak self] result in
                guard let self = self else { return }
                if case .success(let value) = result {
                    let img = value.image
                    iv.image = img
                    let ratio = img.size.height / max(img.size.width, 1)
                    let newH = self.contentWidth * ratio
                    self.heights[i] = newH
                    hc.constant = newH
                    self.view.layoutIfNeeded()
                } else {
                    iv.backgroundColor = .secondarySystemBackground
                }
            }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.urls.isEmpty else { return }
            let idx = min(max(self.initialIndex, 0), self.urls.count - 1)
            self.view.layoutIfNeeded()
            var y: CGFloat = 0
            for j in 0..<idx { y += self.heights[j] }
            let maxY = max(self.scrollView.contentSize.height - self.scrollView.bounds.height, 0)
            self.scrollView.setContentOffset(CGPoint(x: 0, y: min(max(y, 0), maxY)), animated: false)
        }
    }

    @objc private func handleTap() { onTap() }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    func scrollViewDidScroll(_ sv: UIScrollView) {
        guard !heights.isEmpty else { return }
        let offset = sv.contentOffset.y + sv.bounds.height * 0.35
        var acc: CGFloat = 0
        var page = 0
        for i in 0..<heights.count {
            acc += heights[i]
            if acc >= offset { page = i; break }
            page = i
        }
        if page != lastReported {
            lastReported = page
            onPageChange(page)
        }
    }
}