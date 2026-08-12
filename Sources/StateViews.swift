import SwiftUI

/// 加载中
struct LoadingView: View {
    var text: String = "加载中…"
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text).font(.footnote).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 出错重试
struct ErrorRetryView: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("加载失败")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: retry) {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 空状态
struct EmptyStateView: View {
    var icon: String = "tray"
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title).font(.headline).foregroundColor(.secondary)
            if let subtitle = subtitle {
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 章节标题分区标题
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
    }
}