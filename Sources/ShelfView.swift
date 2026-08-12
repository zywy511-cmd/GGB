import SwiftUI

struct ShelfView: View {
    @ObservedObject private var lib = LibraryManager.shared
    @State private var segment: ShelfSegment = .favorites

    enum ShelfSegment: String, CaseIterable, Identifiable {
        case favorites = "收藏"
        case history = "历史"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    ForEach(ShelfSegment.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.vertical, 8)

                if segment == .favorites {
                    favoritesContent
                } else {
                    historyContent
                }
            }
            .navigationTitle("书架")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var favoritesContent: some View {
        Group {
            if lib.favorites.isEmpty {
                EmptyStateView(icon: "heart", title: "还没有收藏",
                              subtitle: "在漫画详情页点击 ♡ 收藏到这里")
            } else {
                ScrollView {
                    ComicGrid(comics: lib.favorites.map { Comic(id: $0.id, title: $0.title, cover: $0.cover) },
                              columns: 3)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var historyContent: some View {
        Group {
            if lib.history.isEmpty {
                EmptyStateView(icon: "clock", title: "还没有阅读记录",
                              subtitle: "开始看一部漫画就会出现在这里")
            } else {
                List {
                    ForEach(lib.history) { rec in
                        NavigationLink {
                            ComicDetailView(comic: Comic(id: rec.id, title: rec.title, cover: rec.cover))
                        } label: {
                            HStack(spacing: 12) {
                                RemoteImage(url: resolveCoverURL(rec.cover), fit: ContentMode.fill)
                                    .frame(width: 44, height: 60)
                                    .cornerRadius(6)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rec.title).font(.subheadline).lineLimit(1)
                                    Text("看到：\(rec.lastChapterTitle)")
                                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    lib.removeHistory(rec.id)
                                } label: {
                                    Image(systemName: "trash").foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { lib.history[$0].id }
                        ids.forEach { lib.removeHistory($0) }
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("清空") { lib.clearHistory() }
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}