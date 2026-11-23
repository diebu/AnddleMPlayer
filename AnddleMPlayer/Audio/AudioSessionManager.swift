import AVFoundation

/// 负责音频会话：后台播放、锁屏控制、拔出耳机暂停都依赖它。
enum AudioSessionManager {
    static func activate() {
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default)
                if #available(iOS 27.0, *) {
                    // iOS 27 起提供真正的异步激活 API。
                    session.activate(options: []) { _, _ in }
                } else {
                    // 旧系统只有同步 API，放到后台线程避免阻塞界面。
                    try session.setActive(true)
                }
            } catch {
                // 极少数情况下（例如被电话占用）会失败，交给系统重试即可
            }
        }
    }

    static func deactivate() {
        Task.detached(priority: .utility) {
            let session = AVAudioSession.sharedInstance()
            if #available(iOS 27.0, *) {
                session.deactivate(options: [.notifyOthersOnDeactivation]) { _, _ in }
            } else {
                try? session.setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
            }
        }
    }
}
