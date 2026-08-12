import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var comics: [Comic] = []
    @State private var page = 1
    @State private var maxPage = 1
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("搜索")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "漫画名 / 作者 / 标签")
                .onSubmit(of: .search) { Task { await search(page: 1, reset: true) } }
                .onChange(of: query) { newValue in
                    Task { await debouncedSearch(newValue) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasSearched {
            EmptyStateView(icon: "magnifyingglass", title: "搜你想看的漫画",
                           subtitle: "输入关键词开始搜索")
        } else if isLoading && comics.isEmpty {
            LoadingView(text: "搜索中…")
        } else if let error = errorMsg, comics.isEmpty {
            ErrorRetryView(message: error) { Task { await search(page: 1, reset: true) } }
        } else if comics.isEmpty {
            EmptyStateView(icon: "tray", title: "没有找到相关漫画")
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
                    if isLoading { ProgressView().frame(maxWidth: .infinity).padding() }
                }
                .padding(.horizontal, 12).padding(.vertical, 12)
            }
        }
    }

    private func debouncedSearch(_ newValue: String) async {
        let q = newValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            comics = []; hasSearched = false; return
        }
        do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
        if query.trimmingCharacters(in: .whitespaces) == q {
            await search(page: 1, reset: true)
        }
    }

    private func maybeLoadMore(current: Comic) {
        guard !isLoading, page < maxPage, hasSearched else { return }
        if let idx = comics.firstIndex(where: { $0.id == current.id }),
           idx >= comics.count - 9 {
            Task { await search(page: page + 1, reset: false) }
        }
    }

    private func search(page p: Int, reset: Bool) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isLoading = true
        errorMsg = nil
        hasSearched = true
        do {
            let result = try await GoDaSource.search(keyword: q, page: p)
            if reset {
                comics = result.comics
                page = 1
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