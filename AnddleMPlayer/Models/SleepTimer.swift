import Foundation

/// 定时停止的两种数法。
enum SleepTimerState: Equatable {
    case off
    /// 按时间：仅在音频引擎实际播放期间消耗
    case time
    /// 按曲目：每播完一首减一
    case tracks(total: Int, remaining: Int)

    var isActive: Bool {
        if case .off = self { return false }
        return true
    }

    var totalTracks: Int {
        if case let .tracks(total, _) = self { return total }
        return 0
    }

    var remainingTracks: Int {
        if case let .tracks(_, remaining) = self { return remaining }
        return 0
    }
}

/// 只有播放引擎确实在前进时才消耗剩余时间。
func sleepRemainingAfter(
    _ remaining: TimeInterval,
    elapsed: TimeInterval,
    isActuallyPlaying: Bool
) -> TimeInterval {
    guard isActuallyPlaying, remaining.isFinite, elapsed.isFinite, elapsed > 0 else {
        return max(0, remaining)
    }
    return max(0, remaining - elapsed)
}
