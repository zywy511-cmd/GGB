import SwiftUI

/// 统一封面地址：相对路径补全世界站域名，绝对路径原样返回
func resolveCoverURL(_ raw: String) -> URL? {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    if s.hasPrefix("http://") || s.hasPrefix("https://") {
        return URL(string: s)
    }
    return URL(string: SourceConfig.current.baseUrl + (s.hasPrefix("/") ? s : "/" + s))
}

struct CoverImageView: View {
    let rawURL: String
    var height: CGFloat
    var body: some View {
        RemoteImage(url: resolveCoverURL(rawURL), fit: .fill)
            .frame(height: height)
            .clipped()
    }
}

/// 网格漫画卡片
struct ComicCard: View {
    let comic: Comic
    var showUpdate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: resolveCoverURL(comic.cover), fit: .fill)
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                    )

                if showUpdate, let sub = comic.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(6)
                        .padding(6)
                }
            }

            Text(comic.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)
                .frame(height: 32, alignment: .top)
        }
    }
}

/// 自适应网格
struct ComicGrid: View {
    let comics: [Comic]
    var columns: Int = 3
    var showUpdate: Bool = false

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 14) {
            ForEach(comics) { comic in
                NavigationLink {
                    ComicDetailView(comic: comic)
                } label: {
                    ComicCard(comic: comic, showUpdate: showUpdate)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

/// 横向滑动的封面条（近期更新用）
struct ComicCarousel: View {
    let comics: [Comic]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(comics) { comic in
                    NavigationLink {
                        ComicDetailView(comic: comic)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RemoteImage(url: resolveCoverURL(comic.cover), fit: .fill)
                                .frame(width: 110, height: 150)
                                .clipped()
                                .cornerRadius(10)
                            Text(comic.title)
                                .font(.caption2)
                                .lineLimit(2)
                                .frame(width: 110, alignment: .top)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 110)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}