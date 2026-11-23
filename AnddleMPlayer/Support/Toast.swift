import Foundation
import Observation

/// 全局轻提示：文件操作和播放器的提示都走这里，顶层只放一个浮层。
@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var message: String?
    private var token = 0

    private init() {}

    func show(_ text: String, seconds: Double = 2.4) {
        message = text
        token += 1
        let current = token
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.token == current else { return }
            self.message = nil
        }
    }
}
