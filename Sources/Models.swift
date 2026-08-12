import Foundation

// MARK: - 漫画列表项

struct Comic: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let cover: String
    var subtitle: String?

    static func == (lhs: Comic, rhs: Comic) -> Bool { lhs.id == rhs.id }
}

// MARK: - 分类

struct CategoryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let param: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CategoryItem, rhs: CategoryItem) -> Bool { lhs.id == rhs.id }
}

struct CategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    let items: [CategoryItem]
}

// MARK: - 首页板块

struct ExploreSection: Identifiable {
    let id = UUID()
    let title: String
    let comics: [Comic]
    let moreParam: String?
    let moreTitle: String?
}

// MARK: - 分页

struct PagedComics {
    let comics: [Comic]
    let maxPage: Int
}

// MARK: - 漫画详情

struct TagGroup: Identifiable, Codable {
    let id = UUID()
    let name: String
    let values: [String]
}

struct ComicDetails: Codable {
    let id: String
    let title: String
    let cover: String
    let description: String
    let tags: [TagGroup]
    let chapters: [ChapterInfo]
    let recommend: [Comic]
    let mangaId: String
}

struct ChapterInfo: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let index: Int
}

// MARK: - 持久化模型

struct FavoriteComic: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let cover: String
    let addedAt: Date
}

struct HistoryRecord: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let cover: String
    let lastChapterId: String
    let lastChapterTitle: String
    let page: Int
    let updatedAt: Date
}