import Foundation
import SwiftSoup

/// 源配置快照（直接读 UserDefaults，线程安全，避免 @AppStorage 的主线程约束）
struct SourceConfig {
    let baseUrl: String
    let apiUrl: String
    let imageUrl: String
    let headers: [String: String]

    static var current: SourceConfig {
        let d = UserDefaults.standard
        let domains = d.string(forKey: "setting_domains").flatMap { $0.isEmpty ? nil : $0 } ?? "godamh.com"
        let api = d.string(forKey: "setting_api").flatMap { $0.isEmpty ? nil : $0 } ?? "v2.apikk.top"
        let image = d.string(forKey: "setting_image").flatMap { $0.isEmpty ? nil : $0 } ?? "c-nd3-1.6wm.top"
        let base = "https://\(domains)"
        return SourceConfig(
            baseUrl: base,
            apiUrl: "https://\(api)/api/v2",
            imageUrl: "https://\(image)",
            headers: [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
                "Referer": base
            ]
        )
    }
}

/// GoDa 漫画数据源 —— 移植自 goda.js
enum GoDaSource {

    // MARK: - 首页

    static func loadExplore() async throws -> [ExploreSection] {
        let cfg = SourceConfig.current
        let html = try await HTTPClient.shared.getString(cfg.baseUrl, headers: cfg.headers)
        let doc = try SwiftSoup.parse(html, cfg.baseUrl)

        var sections: [ExploreSection] = []

        // 近期更新
        var recent: [Comic] = []
        if let unit = try doc.select(".pb-unit-md").first() {
            for a in try unit.select(".slicarda").array() {
                guard let href = try? a.attr("href"), !href.isEmpty else { continue }
                let title = (try? a.select("h3").first()?.text()) ?? ""
                let cover = (try? a.select("img").first()?.attr("src")) ?? ""
                recent.append(Comic(id: href, title: title, cover: cover))
            }
        }
        if !recent.isEmpty {
            sections.append(ExploreSection(title: "近期更新", comics: recent, moreParam: nil, moreTitle: nil))
        }

        // 分类板块
        let cardlists = try doc.select(".cardlist").array()
        let hometitles = try doc.select(".hometitle").array()
        for i in 0..<hometitles.count {
            let titleEl = hometitles[i]
            let title = (try? titleEl.select("h2").first()?.text()) ?? ""
            let param = (try? titleEl.attr("href")) ?? ""
            guard i < cardlists.count else { break }
            let comics = try parseComics(cardlists[i])
            guard !comics.isEmpty else { continue }
            sections.append(ExploreSection(
                title: title,
                comics: comics,
                moreParam: param.isEmpty ? nil : param,
                moreTitle: title.isEmpty ? nil : title
            ))
        }
        return sections
    }

    // MARK: - 分类

    static func loadCategory(param: String, page: Int) async throws -> PagedComics {
        let cfg = SourceConfig.current
        let url = "\(cfg.baseUrl)\(param)/page/\(page)"
        let html = try await HTTPClient.shared.getString(url, headers: cfg.headers)
        let doc = try SwiftSoup.parse(html, cfg.baseUrl)
        return PagedComics(comics: try parseComics(doc), maxPage: parseMaxPage(doc))
    }

    // MARK: - 搜索

    static func search(keyword: String, page: Int) async throws -> PagedComics {
        let cfg = SourceConfig.current
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? keyword
        let url = "\(cfg.baseUrl)/s/\(encoded)?page=\(page)"
        let html = try await HTTPClient.shared.getString(url, headers: cfg.headers)
        let doc = try SwiftSoup.parse(html, cfg.baseUrl)
        return PagedComics(comics: try parseComics(doc), maxPage: parseMaxPage(doc))
    }

    // MARK: - 详情

    static func loadDetail(id: String) async throws -> ComicDetails {
        let cfg = SourceConfig.current
        let html = try await HTTPClient.shared.getString(cfg.baseUrl + id, headers: cfg.headers)
        let doc = try SwiftSoup.parse(html, cfg.baseUrl)

        let rawTitle = (try? doc.select(".text-xl").first()?.text()) ?? ""
        let title = rawTitle.components(separatedBy: "   ").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawTitle
        let cover = (try? doc.select(".object-cover").first()?.attr("src")) ?? ""
        let description = (try? doc.select("p.text-medium").first()?.text()) ?? ""

        // 标签分组
        var tagGroups: [TagGroup] = []
        let infos = try doc.select("div.py-1").array()
        func spanValues(_ el: Element) -> [String] {
            var vals: [String] = []
            for span in (try? el.select("a > span").array()) ?? [] {
                var t = (try? span.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if t.hasSuffix(",") { t = String(t.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines) }
                if !t.isEmpty { vals.append(t) }
            }
            return vals
        }
        if infos.count >= 1 {
            let authors = spanValues(infos[0])
            if !authors.isEmpty { tagGroups.append(TagGroup(name: "作者", values: authors)) }
        }
        if infos.count >= 2 {
            let cats = spanValues(infos[1])
            if !cats.isEmpty { tagGroups.append(TagGroup(name: "类型", values: cats)) }
        }
        if infos.count >= 3 {
            var tags: [String] = []
            for a in (try? infos[2].select("a").array()) ?? [] {
                let t = ((try? a.text()) ?? "")
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "#", with: "")
                if !t.isEmpty { tags.append(t) }
            }
            if !tags.isEmpty { tagGroups.append(TagGroup(name: "标签", values: tags)) }
        }

        // mangaId
        guard let mangaEl = try doc.getElementById("mangachapters"),
              let mangaId = try? mangaEl.attr("data-mid"),
              !mangaId.isEmpty else {
            throw NetworkError.decoding("无法获取漫画ID")
        }

        // 章节列表（API）
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let apiURL = "\(cfg.apiUrl)/manga/get?mid=\(mangaId)&mode=all&t=\(ts)"
        let data = try await HTTPClient.shared.getData(apiURL, headers: cfg.headers)
        var chapters: [ChapterInfo] = []
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = obj["data"] as? [String: Any],
           let chArr = dataObj["chapters"] as? [[String: Any]] {
            var idx = 0
            for ch in chArr {
                guard let cid = stringValue(ch["id"]),
                      let attrs = ch["attributes"] as? [String: Any],
                      let ctitle = stringValue(attrs["title"]) else { continue }
                chapters.append(ChapterInfo(id: "\(mangaId)@\(cid)", title: ctitle, index: idx))
                idx += 1
            }
        }

        // 推荐
        var recommend: [Comic] = []
        for item in try doc.select("div.cardlist > div.pb-2").array() {
            guard let a = try item.select("a").first(),
                  let href = try? a.attr("href"), !href.isEmpty else { continue }
            let rtitle = (try? item.select("h3").first()?.text()) ?? ""
            let rcover = (try? item.select("img").first()?.attr("src")) ?? ""
            recommend.append(Comic(id: href, title: rtitle, cover: rcover))
        }

        return ComicDetails(
            id: id,
            title: title,
            cover: cover,
            description: description,
            tags: tagGroups,
            chapters: chapters,
            recommend: recommend,
            mangaId: mangaId
        )
    }

    // MARK: - 章节图片

    static func loadChapterImages(epId: String) async throws -> [String] {
        guard epId.contains("@") else { throw NetworkError.decoding("无效的章节ID") }
        let cfg = SourceConfig.current
        let parts = epId.components(separatedBy: "@")
        let m = parts[0], c = parts[1]
        let url = "\(cfg.apiUrl)/chapter/getinfo?m=\(m)&c=\(c)"
        let data = try await HTTPClient.shared.getData(url, headers: cfg.headers)

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = obj["data"] as? [String: Any],
              let info = dataObj["info"] as? [String: Any],
              let imagesObj = info["images"] as? [String: Any] else {
            throw NetworkError.decoding("章节数据结构异常")
        }

        var relativeUrls: [String] = []
        if let raw = imagesObj["images"] as? String {
            let decoded = try ChapterImageDecoder.decode(raw)
            relativeUrls = decoded.map { $0.url }
        } else if let arr = imagesObj["images"] as? [[String: Any]] {
            for item in arr {
                if let u = item["url"] as? String { relativeUrls.append(u) }
            }
        } else {
            throw NetworkError.decoding("章节图片格式异常")
        }

        return relativeUrls.map { cfg.imageUrl + $0 }
    }

    // MARK: - 解析辅助

    static func parseComics(_ container: Element) throws -> [Comic] {
        var result: [Comic] = []
        for item in try container.select(".pb-2").array() {
            guard let a = try item.select("a").first(),
                  let href = try? a.attr("href"), !href.isEmpty,
                  let img = try item.select("img").first(),
                  let src = try? img.attr("src"), !src.isEmpty else { continue }
            let title = (try? item.select("h3").first()?.text()) ?? ""
            result.append(Comic(id: href, title: title, cover: src))
        }
        return result
    }

    private static func parseMaxPage(_ doc: Document) -> Int {
        guard let buttons = try? doc.select("button.text-small").array(),
              let last = buttons.last,
              let text = try? last.text() else { return 1 }
        let cleaned = text.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(cleaned) ?? 1
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if let i = any as? Int { return String(i) }
        if let d = any as? Double { return String(Int(d)) }
        return nil
    }
}