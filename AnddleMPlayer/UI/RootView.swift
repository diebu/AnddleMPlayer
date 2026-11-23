import SwiftUI

struct RootView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearance
    @State private var navigationPath: [URL] = []

    var body: some View {
        @Bindable var appState = appState

        NavigationStack(path: $navigationPath) {
            DirectoryView(directory: LibraryPaths.root, isRoot: true)
                .navigationDestination(for: URL.self) { url in
                    DirectoryView(directory: url, isRoot: false)
                }
        }
        .tint(appearance.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.current != nil, !appState.isEditing {
                MiniPlayerBar {
                    appState.showNowPlaying = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.26), value: player.current?.id)
        .animation(.snappy(duration: 0.22), value: appState.isEditing)
        // 用 fullScreenCover 而不是 sheet：sheet 顶部会露出下面一截，不是真正的全屏
        .fullScreenCover(isPresented: $appState.showNowPlaying, onDismiss: focusCurrentDirectory) {
            NowPlayingView(onClose: focusCurrentDirectory)
        }
        .overlay(alignment: .top) {
            ToastView(text: ToastCenter.shared.message)
        }
        .animation(.snappy(duration: 0.25), value: ToastCenter.shared.message)
        // 别的 App 或「文件」把歌曲、文件夹分享过来
        .onOpenURL { url in receive([url]) }
        .accessibilityIdentifier("app.root")
    }

    /// 收起播放页时，让底下的列表停留在当前歌曲所在目录。
    /// 在封面消失前先更新路径，避免先闪回根目录再跳转。
    private func focusCurrentDirectory() {
        appState.isEditing = false
        navigationPath = currentDirectoryPath()
    }

    private func currentDirectoryPath() -> [URL] {
        guard let current = player.current else { return [] }
        var components = current.relativePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard components.count > 1 else { return [] }
        components.removeLast()

        var path: [URL] = []
        var directory = LibraryPaths.root
        for component in components {
            let next = directory.appendingPathComponent(component, isDirectory: true)
            guard FileService.isDirectory(next) else { break }
            path.append(next)
            directory = next
        }
        return path
    }

    private func receive(_ urls: [URL]) {
        Task {
            let count = await Task.detached(priority: .userInitiated) {
                FileService.accept(urls)
            }.value
            if count > 0 {
                ToastCenter.shared.show(L10n.received(count))
                appState.libraryVersion += 1
            } else {
                ToastCenter.shared.show(L10n.receiveFailed)
            }
        }
    }
}
