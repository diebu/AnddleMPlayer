import Observation
import SwiftUI

/// 黑底、白字，强调色可在琥珀色与红色之间切换。所有灰都是白色的不同透明度。
enum Palette {
    static let background = Color.black
    static let surface = Color(white: 0.08)          // 迷你条、工具栏、弹出面板的抬升面
    static let text = Color.white
    static let sub = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.46)
    static let line = Color.white.opacity(0.14)
    static let fill = Color.white.opacity(0.08)
    static let accentInk = Color.black
}

enum PlayerColorTheme: String {
    case amber
    case red

    var accent: Color {
        switch self {
        case .amber: return Color(red: 1.0, green: 0.69, blue: 0.0)         // #ffb000
        case .red: return Color(red: 1.0, green: 0.29, blue: 0.32)          // #ff4a52
        }
    }

    var dangerFill: Color {
        switch self {
        case .amber: return Color(red: 0.82, green: 0.25, blue: 0.035)      // #d14009
        case .red: return Color(red: 0.816, green: 0.008, blue: 0.106)      // #d0021b
        }
    }
}

@MainActor
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()
    private static let key = "playerColorTheme"

    private(set) var theme: PlayerColorTheme

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        theme = PlayerColorTheme(rawValue: saved ?? "") ?? .amber
    }

    var accent: Color { theme.accent }
    var dangerFill: Color { theme.dangerFill }

    func select(_ theme: PlayerColorTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.key)
    }
}

/// 跨屏幕共享的一点界面状态。
@MainActor
@Observable
final class AppState {
    var showNowPlaying = false
    var isEditing = false
    /// 库内容变了（比如从别的 App 分享进来）就加一，列表据此重新载入
    var libraryVersion = 0

    /// 左右滑动一次跳转的秒数
    var swipeSeekSeconds: Int {
        didSet { UserDefaults.standard.set(swipeSeekSeconds, forKey: "swipeSeekSeconds") }
    }
    /// 双指单击前进的秒数
    var twoFingerForwardSeconds: Int {
        didSet { UserDefaults.standard.set(twoFingerForwardSeconds, forKey: "twoFingerForwardSeconds") }
    }

    init() {
        let defaults = UserDefaults.standard
        let swipe = defaults.integer(forKey: "swipeSeekSeconds")
        let doubleTap = defaults.integer(forKey: "twoFingerForwardSeconds")
        swipeSeekSeconds = swipe > 0 ? swipe : 10
        twoFingerForwardSeconds = doubleTap > 0 ? doubleTap : 30
    }
}
