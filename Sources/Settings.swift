import Foundation
import Combine
import UIKit

/// 阅读模式
enum ReaderMode: String, Codable, CaseIterable, Identifiable {
    case webtoon
    case paged
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .webtoon: return "竖向滚动"
        case .paged: return "横向翻页"
        }
    }
}

/// 全局设置：域名配置 + 阅读偏好。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let domains = "setting_domains"
        static let api = "setting_api"
        static let image = "setting_image"
        static let readerMode = "setting_readerMode"
        static let keepAwake = "setting_keepAwake"
    }

    static let defaultDomains = "godamh.com"
    static let defaultAPI = "v2.apikk.top"
    static let defaultImage = "c-nd3-1.6wm.top"

    @Published var domains: String {
        didSet { UserDefaults.standard.set(domains, forKey: Keys.domains) }
    }
    @Published var api: String {
        didSet { UserDefaults.standard.set(api, forKey: Keys.api) }
    }
    @Published var image: String {
        didSet { UserDefaults.standard.set(image, forKey: Keys.image) }
    }
    @Published var readerMode: ReaderMode {
        didSet { UserDefaults.standard.set(readerMode.rawValue, forKey: Keys.readerMode) }
    }
    @Published var keepAwake: Bool {
        didSet { UserDefaults.standard.set(keepAwake, forKey: Keys.keepAwake) }
    }

    private init() {
        let d = UserDefaults.standard
        let dm = d.string(forKey: Keys.domains) ?? ""
        let ap = d.string(forKey: Keys.api) ?? ""
        let im = d.string(forKey: Keys.image) ?? ""
        domains = dm.isEmpty ? AppSettings.defaultDomains : dm
        api = ap.isEmpty ? AppSettings.defaultAPI : ap
        image = im.isEmpty ? AppSettings.defaultImage : im
        readerMode = ReaderMode(rawValue: d.string(forKey: Keys.readerMode) ?? "") ?? .webtoon
        keepAwake = d.bool(forKey: Keys.keepAwake)
    }

    func resetDomains() {
        domains = AppSettings.defaultDomains
        api = AppSettings.defaultAPI
        image = AppSettings.defaultImage
    }

    var baseUrl: String { "https://\(domains)" }
    var apiUrl: String { "https://\(api)/api/v2" }
    var imageUrl: String { "https://\(image)" }
}