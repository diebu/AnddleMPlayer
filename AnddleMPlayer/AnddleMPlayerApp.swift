import SwiftUI

@main
struct AnddleMPlayerApp: App {
    @State private var player = AudioPlayer()
    @State private var appState = AppState()
    @State private var appearance = AppearanceStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LibraryPaths.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(appState)
                .environment(appearance)
                .preferredColorScheme(.dark)
                .task { @MainActor in
                    LibraryPaths.bootstrap()
                    NowPlayingCenter.shared.configure(player: player)
                    // 启动时清一次已经不存在的标签缓存与封面
                    Task.detached(priority: .utility) {
                        let alive = Set(FileService.allAudioURLs().map { LibraryPaths.relativePath(of: $0) })
                        await MetadataStore.shared.prune(existing: alive)
                        await ArtworkStore.shared.purgeOrphans(keeping: alive)
                    }
                    // 上次「拷贝到 App」还没来得及搬出来的，一起收了
                    let drained = await Task.detached(priority: .utility) {
                        FileService.drainInbox()
                    }.value
                    if drained > 0 { appState.libraryVersion += 1 }

                    // 只有确实恢复出当前歌曲时才进入播放页；没有内容就直接留在列表。
                    if player.restoreLastSession() {
                        appState.showNowPlaying = true
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        // 用户可能在「文件」App 里删掉了试听音乐。
                        LibraryPaths.bootstrap()
                        // 用户可能在「文件」App 里删除了当前歌曲。
                        if player.discardCurrentIfMissing() {
                            appState.showNowPlaying = false
                            appState.libraryVersion += 1
                        }
                    } else {
                        // 切到后台就把播放进度落盘
                        PlaybackProgress.shared.flush()
                    }
                }
        }
    }
}
