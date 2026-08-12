import SwiftUI

struct ComicDetailView: View {
    let comic: Comic

    @StateObject private var lib = LibraryManager.shared
    @State private var details: ComicDetails?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showReader = false
    @State private var startChapterIndex = 0
    @State private var fav: Bool = false

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error = errorMsg {
                ErrorRetryView(message: error) { Task { await load() } }
            } else if let d = details {
                detailContent(d)
            } else {
                EmptyStateView(title: "无数据")
            }
        }
        .navigationTitle(details?.title ?? comic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    lib.toggleFavorite(comic)
                    fav = lib.isFavorite(comic.id)
                } label: {
                    Image(systemName: fav ? "heart.fill" : "heart")
                        .foregroundColor(fav ? .pink : .primary)
                }
            }
        }
        .task { await load() }
        .onAppear { fav = LibraryManager.shared.isFavorite(comic.id) }
        .fullScreenCover(isPresented: $showReader) {
            if let d = details, !d.chapters.isEmpty {
                ReaderView(comic: comic, details: d, startIndex: startChapterIndex)
            }
        }
    }

    private func detailContent(_ d: ComicDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 头部
                HStack(alignment: .top, spacing: 14) {
                    CoverImageView(rawURL: d.cover, height: 160)
                        .frame(width: 115)
                        .cornerRadius(12)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(d.title).font(.title3.bold())
                        if !d.tags.isEmpty {
                            ForEach(d.tags) { g in
                                if !g.values.isEmpty {
                                    (Text("\(g.name)：").foregroundColor(.secondary) +
                                     Text(g.values.joined(separator: "、")))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        Button {
                            beginReading()
                        } label: {
                            Label("开始阅读", systemImage: "book.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 12)

                if !d.description.isEmpty {
                    Text(d.description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }

                // 章节
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "章节（共 \(d.chapters.count) 话）")
                    chapterList(d)
                }

                // 推荐
                if !d.recommend.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "你可能会喜欢")
                        ComicGrid(comics: Array(d.recommend.prefix(6)), columns: 3)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    private func chapterList(_ d: ComicDetails) -> some View {
        let ordered = d.chapters.reversed()
        return LazyVStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { idx, ch in
                Button {
                    if let pos = d.chapters.firstIndex(where: { $0.id == ch.id }) {
                        startChapterIndex = pos
                    }
                    showReader = true
                } label: {
                    HStack {
                        if LibraryManager.shared.isRead(comicId: d.id, chapterId: ch.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                        Text(ch.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(idx % 2 == 0 ? Color(.secondarySystemBackground).opacity(0.4) : Color.clear)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func beginReading() {
        guard let d = details, !d.chapters.isEmpty else { return }
        if let prog = LibraryManager.shared.progress(for: d.id),
           let pos = d.chapters.firstIndex(where: { $0.id == prog.lastChapterId }) {
            startChapterIndex = pos
        } else {
            startChapterIndex = d.chapters.count - 1
        }
        showReader = true
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            details = try await GoDaSource.loadDetail(id: comic.id)
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
        fav = LibraryManager.shared.isFavorite(comic.id)
    }
}