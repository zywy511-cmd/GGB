import SwiftUI

struct CategoryView: View {
    var initialParam: String? = nil
    var initialTitle: String? = nil

    @State private var groups: [CategoryGroup] = [
        CategoryGroup(name: "类型", items: ExplorePresets.categories),
        CategoryGroup(name: "标签", items: ExplorePresets.tags)
    ]
    @State private var activeGroup = 0
    @State private var param: String
    @State private var title: String

    @State private var comics: [Comic] = []
    @State private var page = 1
    @State private var maxPage = 1
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var didLoadOnce = false

    init(initialParam: String? = nil, initialTitle: String? = nil) {
        self.initialParam = initialParam
        self.initialTitle = initialTitle
        _param = State(initialValue: initialParam ?? ExplorePresets.categories[0].param)
        _title = State(initialValue: initialTitle ?? ExplorePresets.categories[0].name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupToggle
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(groups[activeGroup].items) { item in
                            Button {
                                selectCategory(item)
                            } label: {
                                Text(item.name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(item.param == param ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundColor(item.param == param ? .white : .primary)
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }

                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { if !didLoadOnce { await load(page: 1, reset: true) } }
    }

    private var groupToggle: some View {
        Picker("", selection: $activeGroup) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { idx, g in
                Text(g.name).tag(idx)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12).padding(.top, 8)
        .onChange(of: activeGroup) { _ in
            let first = groups[activeGroup].items[0]
            selectCategory(first)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && comics.isEmpty {
            LoadingView()
        } else if let error = errorMsg, comics.isEmpty {
            ErrorRetryView(message: error) { Task { await load(page: 1, reset: true) } }
        } else if comics.isEmpty {
            EmptyStateView(title: "暂无内容", subtitle: "换个分类试试")
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    ForEach(comics) { comic in
                        NavigationLink {
                            ComicDetailView(comic: comic)
                        } label: {
                            ComicCard(comic: comic).foregroundColor(.primary)
                        }
                        .onAppear { maybeLoadMore(current: comic) }
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 12)
            }
            .refreshable { await load(page: 1, reset: true) }
        }
    }

    private func selectCategory(_ item: CategoryItem) {
        guard item.param != param else { return }
        param = item.param
        title = item.name
        Task { await load(page: 1, reset: true) }
    }

    private func maybeLoadMore(current: Comic) {
        guard !isLoading, page < maxPage else { return }
        if let idx = comics.firstIndex(where: { $0.id == current.id }),
           idx >= comics.count - 9 {
            Task { await load(page: page + 1, reset: false) }
        }
    }

    private func load(page p: Int, reset: Bool) async {
        isLoading = true
        errorMsg = nil
        do {
            let result = try await GoDaSource.loadCategory(param: param, page: p)
            if reset {
                comics = result.comics
                page = 1
                didLoadOnce = true
            } else {
                let existing = Set(comics.map { $0.id })
                comics.append(contentsOf: result.comics.filter { !existing.contains($0.id) })
                page = p
            }
            maxPage = max(maxPage, result.maxPage)
        } catch {
            if comics.isEmpty {
                errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoading = false
    }
}