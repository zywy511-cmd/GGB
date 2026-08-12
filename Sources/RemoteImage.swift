import Foundation
import SwiftUI
import Kingfisher

/// 给 Kingfisher 的下载请求附加自定义 Header（UA / Referer）
struct GHeaderModifier: ImageDownloadRequestModifier {
    let headers: [String: String]

    func modified(for request: URLRequest) -> URLRequest? {
        var req = request
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        return req
    }
}

/// 站点请求头（图片与网页一致）
var siteImageHeaders: [String: String] {
    SourceConfig.current.headers
}

enum ImagePrefs {
    /// 统一配置 Kingfisher（全局只调用一次）
    static func configure() {
        let cfg = KingfisherManager.shared.downloader.sessionConfiguration
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 60
        cfg.httpMaximumConnectionsPerHost = 8
        KingfisherManager.shared.downloader.sessionConfiguration = cfg
    }
}

/// 远程图片视图：支持自定义 Header、占位、淡入、失败重试
struct RemoteImage: View {
    let url: URL?
    var headers: [String: String] = siteImageHeaders
    var placeholder: Color = Color(.secondarySystemBackground)
    var fit: ContentMode = .fill
    var fade: Double = 0.25

    var body: some View {
        Group {
            if let url = url {
                KFImage(url)
                    .requestModifier(GHeaderModifier(headers: headers))
                    .placeholder { placeholder }
                    .retry(maxCount: 3, interval: .seconds(1))
                    .fade(duration: fade)
                    .onFailure { _ in }
                    .resizable()
                    .aspectRatio(contentMode: fit)
            } else {
                placeholder
            }
        }
    }
}