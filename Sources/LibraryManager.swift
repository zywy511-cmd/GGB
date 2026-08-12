import Foundation
import Combine

/// 书架数据：收藏、历史、已读标记、阅读进度。持久化为 Documents 下的 JSON。
final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published private(set) var favorites: [FavoriteComic] = []
    @Published private(set) var history: [HistoryRecord] = []
    @Published private(set) var readMarks: [String: Set<String>] = [:]

    private let favFile: URL
    private let hisFile: URL
    private let readFile: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        favFile = dir.appendingPathComponent("favorites.json")
        hisFile = dir.appendingPathComponent("history.json")
        readFile = dir.appendingPathComponent("readmarks.json")
        load()
    }

    // MARK: - 收藏

    func isFavorite(_ id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    func toggleFavorite(_ comic: Comic) {
        if let idx = favorites.firstIndex(where: { $0.id == comic.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(FavoriteComic(id: comic.id, title: comic.title,
                                           cover: comic.cover, addedAt: Date()), at: 0)
        }
        saveFavorites()
    }

    func toggleFavorite(id: String, title: String, cover: String) {
        toggleFavorite(Comic(id: id, title: title, cover: cover))
    }

    func removeFavorite(_ id: String) {
        favorites.removeAll { $0.id == id }
        saveFavorites()
    }

    // MARK: - 历史 & 进度

    func recordHistory(comicId: String, title: String, cover: String,
                       chapterId: String, chapterTitle: String, page: Int) {
        history.removeAll { $0.id == comicId }
        let record = HistoryRecord(id: comicId, title: title, cover: cover,
                                   lastChapterId: chapterId, lastChapterTitle: chapterTitle,
                                   page: page, updatedAt: Date())
        history.insert(record, at: 0)
        if history.count > 300 { history = Array(history.prefix(300)) }
        saveHistory()
        markRead(comicId: comicId, chapterId: chapterId)
    }

    func progress(for comicId: String) -> HistoryRecord? {
        history.first { $0.id == comicId }
    }

    func removeHistory(_ id: String) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func clearAll() {
        favorites.removeAll()
        history.removeAll()
        readMarks.removeAll()
        saveFavorites()
        saveHistory()
        saveReadMarks()
    }

    // MARK: - 已读标记

    func markRead(comicId: String, chapterId: String) {
        var set = readMarks[comicId] ?? []
        set.insert(chapterId)
        readMarks[comicId] = set
        saveReadMarks()
    }

    func isRead(comicId: String, chapterId: String) -> Bool {
        readMarks[comicId]?.contains(chapterId) ?? false
    }

    // MARK: - 持久化

    private func load() {
        favorites = decode([FavoriteComic].self, from: favFile) ?? []
        history = decode([HistoryRecord].self, from: hisFile) ?? []
        if let raw = decode([String: [String]].self, from: readFile) {
            readMarks = raw.mapValues { Set($0) }
        }
    }

    private func saveFavorites() { encode(favorites, to: favFile) }
    private func saveHistory() { encode(history, to: hisFile) }
    private func saveReadMarks() {
        let raw = readMarks.mapValues { Array($0) }
        encode(raw, to: readFile)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}