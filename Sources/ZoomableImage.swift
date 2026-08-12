import SwiftUI
import Kingfisher
import UIKit

/// 单页可缩放图片（横向翻页模式用）
struct ZoomableImage: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.maximumZoomScale = 4
        scroll.minimumZoomScale = 1
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delegate = context.coordinator
        scroll.backgroundColor = .black

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(iv)

        let modifier = GHeaderModifier(headers: SourceConfig.current.headers)
        let options: KingfisherOptionsInfo = [.requestModifier(modifier)]
        iv.kf.setImage(with: url, options: options) { result in
            if case .success(let v) = result {
                DispatchQueue.main.async {
                    iv.image = v.image
                    let size = v.image.size
                    let sw = UIScreen.main.bounds.width
                    let sh = UIScreen.main.bounds.height
                    let ratio = min(sw / max(size.width, 1), sh / max(size.height, 1))
                    let w = size.width * ratio
                    let h = size.height * ratio
                    iv.frame = CGRect(x: 0, y: 0, width: w, height: h)
                    scroll.contentSize = CGSize(width: w, height: h)
                    iv.center = CGPoint(x: sw / 2, y: sh / 2)
                }
            }
        }
        context.coordinator.imageView = iv
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let iv = imageView else { return }
            let sw = UIScreen.main.bounds.width
            let sh = UIScreen.main.bounds.height
            let cw = scrollView.contentSize.width
            let ch = scrollView.contentSize.height
            iv.center = CGPoint(x: max(sw, cw) / 2, y: max(sh, ch) / 2)
        }
    }
}