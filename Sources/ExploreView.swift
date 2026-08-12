import SwiftUI

struct ExploreView: View {
    @State private var sections: [ExploreSection] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var selectedCategory: CategoryItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("G漫画")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SearchView()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
                .refreshable { await load() }
        }
        .task { if sections.isEmpty { await load() } }
        .sheet(item: $selectedCategory) { item in
            CategoryView(initialParam: item.param, initialTitle: item.name)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && sections.isEmpty {
            LoadingView()
        } else if let error = errorMsg, sections.isEmpty {
            ErrorRetryView(message: error) { Task { await load() } }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    categoryChips
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(
                                title: section.title,
                                actionTitle: (section.moreParam?.isEmpty == false) ? "更多" : nil,
                                action: (section.moreParam?.isEmpty == false) ? {
                                    if let param = section.moreParam {
                                        selectedCategory = CategoryItem(
                                            name: section.moreTitle ?? section.title,
                                            param: param
                                        )
                                    }
                                } : nil
                            )
                            if section.title == "近期更新" {
                                ComicCarousel(comics: section.comics)
                            } else {
                                ComicGrid(comics: Array(section.comics.prefix(6)), columns: 3)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExplorePresets.categories) { item in
                    Button {
                        selectedCategory = item
                    } label: {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            sections = try await GoDaSource.loadExplore()
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

enum ExplorePresets {
    static let categories: [CategoryItem] = [
        CategoryItem(name: "全部", param: "/manga"),
        CategoryItem(name: "韩漫", param: "/manga-genre/kr"),
        CategoryItem(name: "热门漫画", param: "/manga-genre/hots"),
        CategoryItem(name: "国漫", param: "/manga-genre/cn"),
        CategoryItem(name: "其他", param: "/manga-genre/qita"),
        CategoryItem(name: "日漫", param: "/manga-genre/jp"),
        CategoryItem(name: "欧美", param: "/manga-genre/ou-mei")
    ]

    static let tags: [CategoryItem] = [
        CategoryItem(name: "复仇", param: "/manga-tag/fuchou"),
        CategoryItem(name: "古风", param: "/manga-tag/gufeng"),
        CategoryItem(name: "奇幻", param: "/manga-tag/qihuan"),
        CategoryItem(name: "逆袭", param: "/manga-tag/nixi"),
        CategoryItem(name: "异能", param: "/manga-tag/yineng"),
        CategoryItem(name: "穿越", param: "/manga-tag/chuanyue"),
        CategoryItem(name: "热血", param: "/manga-tag/rexue"),
        CategoryItem(name: "纯爱", param: "/manga-tag/chunai"),
        CategoryItem(name: "系统", param: "/manga-tag/xitong"),
        CategoryItem(name: "重生", param: "/manga-tag/zhongsheng"),
        CategoryItem(name: "冒险", param: "/manga-tag/maoxian"),
        CategoryItem(name: "恋爱", param: "/manga-tag/lianai"),
        CategoryItem(name: "玄幻", param: "/manga-tag/xuanhuan"),
        CategoryItem(name: "科幻", param: "/manga-tag/kehuan"),
        CategoryItem(name: "治愈", param: "/manga-tag/zhiyu"),
        CategoryItem(name: "都市", param: "/manga-tag/doushi"),
        CategoryItem(name: "末日", param: "/manga-tag/mori"),
        CategoryItem(name: "悬疑", param: "/manga-tag/xuanyi"),
        CategoryItem(name: "修仙", param: "/manga-tag/xiuxian"),
        CategoryItem(name: "战斗", param: "/manga-tag/zhandou")
    ]
}