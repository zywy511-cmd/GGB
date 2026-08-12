import SwiftUI

struct ReaderView: View {
    let comic: Comic
    let details: ComicDetails
    @State var startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var images: [URL] = []
    @State private var currentIndex: Int = 0
    @State private var currentChapterIndex: Int
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showControls = true
    @State private var showChapterSheet = false
    @State private var brightness: Double = UIScreen.main.brightness

    init(comic: Comic, details: ComicDetails, startIndex: Int) {
        self.comic = comic
        self.details = details
        self._startIndex = State(initialValue: startIndex)
        self._currentChapterIndex = State(initialValue: startIndex)
        self._currentIndex = State(initialValue: 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if showControls { toolbarOverlay }
        }
        .sheet(isPresented: $showChapterSheet) {
            chapterSheet
        }
        .statusBar(hidden: !showControls)
        .preferredColorScheme(.dark)
        .onChange(of: currentIndex) { _ in recordProgress() }
        .onChange(of: currentChapterIndex) { _ in
            Task { await loadChapter(at: currentChapterIndex) }
        }
        .onAppear {
            UIScreen.main.brightness = brightness
            Task { await loadChapter(at: currentChapterIndex) }
        }
        .onDisappear { recordProgress() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().progressViewStyle(.circular).tint(.white)
        } else if let error = errorMsg, images.isEmpty {
            VStack(spacing: 12) {
                Text("加载失败").foregroundColor(.white)
                Text(error).font(.footnote).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                Button("重试") { Task { await loadChapter(at: currentChapterIndex) } }
                    .foregroundColor(.accentColor)
            }
        } else if settings.readerMode == .webtoon {
            WebtoonScrollView(urls: images, initialIndex: currentIndex,
                              onPageChange: { page in currentIndex = page },
                              onTap: { withAnimation { showControls.toggle() } })
                .ignoresSafeArea()
        } else {
            if !images.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, url in
                        ZoomableImage(url: url)
                            .tag(idx)
                            .ignoresSafeArea()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { showControls.toggle() } }
                )
            }
        }
    }

    private var toolbarOverlay: some View {
        VStack {
            // 顶栏
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.title3).foregroundColor(.white)
                        .padding(10).background(Color.black.opacity(0.4)).clipShape(Circle())
                }
                Spacer()
                Text(details.chapters.isEmpty ? "" : details.chapters[currentChapterIndex].title)
                    .font(.subheadline).foregroundColor(.white).lineLimit(1)
                Spacer()
                Button { showChapterSheet = true } label: {
                    Image(systemName: "list.bullet").font(.title3).foregroundColor(.white)
                        .padding(10).background(Color.black.opacity(0.4)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)

            Spacer()

            // 底栏
            VStack(spacing: 10) {
                HStack {
                    Button { gotoPrevChapter() } label: {
                        Image(systemName: "chevron.left").foregroundColor(.white)
                    }
                    .disabled(currentChapterIndex <= 0)
                    Text("\(currentIndex + 1) / \(max(images.count, 1))")
                        .font(.footnote).foregroundColor(.white)
                    Button { gotoNextChapter() } label: {
                        Image(systemName: "chevron.right").foregroundColor(.white)
                    }
                    .disabled(currentChapterIndex >= details.chapters.count - 1)
                }
                HStack(spacing: 16) {
                    Button { settings.readerMode = (settings.readerMode == .webtoon ? .paged : .webtoon) } label: {
                        Image(systemName: settings.readerMode == .webtoon ? "rectangle.split.3x3" : "rotate")
                            .foregroundColor(.white)
                    }
                    Image(systemName: "sun.min").foregroundColor(.gray)
                    Slider(value: $brightness, in: 0.2...1.0)
                        .onChange(of: brightness) { v in UIScreen.main.brightness = v }
                        .frame(width: 140)
                    Image(systemName: "sun.max").foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 18)
            .background(Color.black.opacity(0.55))
        }
        .ignoresSafeArea(edges: .top)
    }

    private var chapterSheet: some View {
        NavigationStack {
            List {
                let ordered = details.chapters.reversed()
                ForEach(Array(ordered.enumerated()), id: \.element.id) { _, ch in
                    Button {
                        if let pos = details.chapters.firstIndex(where: { $0.id == ch.id }) {
                            currentChapterIndex = pos
                            showChapterSheet = false
                        }
                    } label: {
                        HStack {
                            Text(ch.title).foregroundColor(.primary)
                            Spacer()
                            if pos(details: details, id: ch.id) == currentChapterIndex {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showChapterSheet = false }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func pos(details: ComicDetails, id: String) -> Int {
        details.chapters.firstIndex(where: { $0.id == id }) ?? -1
    }

    private func gotoPrevChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
    }

    private func gotoNextChapter() {
        guard currentChapterIndex < details.chapters.count - 1 else { return }
        currentChapterIndex += 1
    }

    private func loadChapter(at index: Int) async {
        guard details.chapters.indices.contains(index) else { return }
        isLoading = true
        errorMsg = nil
        let epId = details.chapters[index].id
        let prog = LibraryManager.shared.progress(for: details.id)
        let resume = (prog?.lastChapterId == epId) ? (prog?.page ?? 0) : 0
        currentIndex = max(0, min(resume, max(details.chapters.count - 1, 0)))
        do {
            let urls = try await GoDaSource.loadChapterImages(epId: epId)
            images = urls.compactMap { URL(string: $0) }
            currentIndex = max(0, min(resume, max(images.count - 1, 0)))
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
        recordProgress()
    }

    private func recordProgress() {
        guard details.chapters.indices.contains(currentChapterIndex) else { return }
        let ch = details.chapters[currentChapterIndex]
        LibraryManager.shared.recordHistory(
            comicId: details.id,
            title: details.title,
            cover: details.cover,
            chapterId: ch.id,
            chapterTitle: ch.title,
            page: currentIndex
        )
    }
}