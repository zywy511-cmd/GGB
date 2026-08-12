import SwiftUI
import Kingfisher

@main
struct GGBApp: App {
    @ObservedObject private var settings = AppSettings.shared

    init() {
        ImagePrefs.configure()
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = UInt(500 * 1024 * 1024)
        KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = UInt(120 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ExploreView()
                    .tabItem { Label("首页", systemImage: "house.fill") }
                CategoryView()
                    .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }
                ShelfView()
                    .tabItem { Label("书架", systemImage: "books.vertical.fill") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
            }
            .accentColor(.accentColor)
            .onReceive(settings.$keepAwake) { awake in
                UIApplication.shared.isIdleTimerDisabled = awake
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
            }
        }
    }
}