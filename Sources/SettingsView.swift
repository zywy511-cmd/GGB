import SwiftUI
import Kingfisher

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var lib = LibraryManager.shared

    @State private var showResetConfirm = false
    @State private var showClearConfirm = false
    @State private var cacheSizeText = "计算中…"
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    domainRow(title: "漫画站", text: $settings.domains, placeholder: AppSettings.defaultDomains)
                    domainRow(title: "接口", text: $settings.api, placeholder: AppSettings.defaultAPI)
                    domainRow(title: "图片", text: $settings.image, placeholder: AppSettings.defaultImage)
                    Button("恢复默认域名") { showResetConfirm = true }
                } header: {
                    Text("数据源域名")
                } footer: {
                    Text("网站更换域名时在此修改即可继续使用，无需更新 App。")
                }

                Section("阅读设置") {
                    Picker("阅读模式", selection: $settings.readerMode) {
                        ForEach(ReaderMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    Toggle("阅读时屏幕常亮", isOn: $settings.keepAwake)
                }

                Section("数据与缓存") {
                    HStack {
                        Text("图片缓存")
                        Spacer()
                        Text(cacheSizeText).foregroundColor(.secondary)
                    }
                    Button("清理图片缓存") {
                        KingfisherManager.shared.cache.clearMemoryCache()
                        KingfisherManager.shared.cache.clearDiskCache {
                            toast = "图片缓存已清理"
                            refreshCacheSize()
                        }
                    }
                    Button("清空收藏与历史") { showClearConfirm = true }
                        .foregroundColor(.red)
                }

                Section("关于") {
                    HStack {
                        Text("应用名称"); Spacer()
                        Text("GGB漫画").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("版本"); Spacer()
                        Text(appVersion).foregroundColor(.secondary)
                    }
                    Text("第三方漫画阅读器，内容来自公开网络接口，仅供学习交流使用。")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshCacheSize() }
            .alert("恢复默认域名？", isPresented: $showResetConfirm) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    settings.resetDomains()
                    toast = "已恢复默认域名"
                }
            }
            .alert("清空收藏与历史？", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    lib.clearAll()
                    toast = "已清空"
                }
            }
            .overlay(alignment: .bottom) { toastView }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = toast {
            Text(toast)
                .font(.footnote)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.bottom, 30)
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { self.toast = nil }
                    }
                }
        }
    }

    private func domainRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(title).frame(width: 60, alignment: .leading)
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .foregroundColor(.secondary)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return v
    }

    private func refreshCacheSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                let mb = Double(size) / 1024 / 1024
                cacheSizeText = String(format: "%.1f MB", mb)
            case .failure:
                cacheSizeText = "—"
            }
        }
    }
}