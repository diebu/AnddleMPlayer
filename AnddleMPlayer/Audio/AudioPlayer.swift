import AVFoundation
import Foundation
import Observation

/// 播放引擎：队列、进度、随机 / 循环、倍速、定时停止。
@MainActor
@Observable
final class AudioPlayer {
    private let engine = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var ticker: Task<Void, Never>?
    private var sleepLastTickUptime: TimeInterval?
    private var history: [Int] = []
    private var brokenSkips = 0

    /// 上次选中并加载的歌曲路径，用来在下次启动时恢复现场
    private static let lastPathKey = "lastPlayedPath"

    private(set) var queue: [MusicFile] = []
    private(set) var index: Int = -1
    private(set) var isPlaying = false
    var elapsed: Double = 0
    var duration: Double = 0
    var repeatMode: RepeatMode = .off
    private(set) var isShuffled = false
    /// 拖动进度条期间忽略时钟回调
    var isScrubbing = false
    private(set) var speed: Double = 1.0
    private(set) var sleepTimer: SleepTimerState = .off
    private(set) var sleepRemaining: TimeInterval = 0
    /// 底下那个「一键倒计时」用的预设，跟着设置里选过的走
    var timerPresetMinutes: Double = 30 {
        didSet { UserDefaults.standard.set(timerPresetMinutes, forKey: "timerPresetMinutes") }
    }
    // 音量交给系统（音量键 / 控制中心），App 不自己管

    var current: MusicFile? {
        guard index >= 0, index < queue.count else { return nil }
        return queue[index]
    }

    var upNext: [MusicFile] {
        guard !queue.isEmpty else { return [] }
        if isShuffled { return queue.filter { $0.id != current?.id } }
        let start = max(0, index)
        return Array(queue.dropFirst(start + 1))
    }

    init() {
        engine.actionAtItemEnd = .pause
        engine.volume = 1
        speed = ((UserDefaults.standard.object(forKey: "speed") as? Double) ?? 1.0)
            .clamped(to: 0.5...2.0)
        timerPresetMinutes = (UserDefaults.standard.object(forKey: "timerPresetMinutes") as? Double) ?? 30

        timeObserver = engine.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite, !self.isScrubbing {
                    self.elapsed = max(0, seconds)
                }
                if let itemDuration = self.engine.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                // 记录播到哪儿了，列表里的进度条靠它
                if let file = self.current, !self.isScrubbing {
                    let knownDuration = self.duration > 0
                        ? self.duration
                        : file.duration
                    PlaybackProgress.shared.record(
                        file.relativePath,
                        seconds: max(0, seconds),
                        duration: knownDuration
                    )
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self,
                      let item = note.object as? AVPlayerItem,
                      item === self.engine.currentItem else { return }
                self.isPlaying = false
                self.advance(forward: true, userInitiated: false)
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self,
                      let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                    return
                }

                switch type {
                case .began:
                    self.pauseForSystemInterruption()
                case .ended:
                    // 不自动续播；若其他 App 仍占用音频，界面继续保持暂停。
                    self.pauseForSystemInterruption()
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: 播放

    func play(_ file: MusicFile, in list: [MusicFile], autoplay: Bool = true) {
        commitCurrentProgress()
        queue = list.isEmpty ? [file] : list
        index = queue.firstIndex { $0.id == file.id } ?? 0
        history.removeAll()
        brokenSkips = 0
        load(autoplay: autoplay)
    }

    /// 恢复上次选中的歌曲和所在目录队列（不自动出声）。
    /// 不要求退出前仍处于播放状态，暂停退出、被系统结束后也能恢复。
    /// 队列用它所在目录的音频重建，这样上一首 / 下一首仍然可用。
    @discardableResult
    func restoreLastSession() -> Bool {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: Self.lastPathKey) else { return false }
        let url = LibraryPaths.url(forRelativePath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        let store = MetadataStore.shared
        let siblings = FileService.audioURLs(in: url.deletingLastPathComponent()).map { store.musicFile(for: $0) }
        let file = store.musicFile(for: url)
        play(file, in: siblings.isEmpty ? [file] : siblings, autoplay: false)
        return current != nil
    }

    func toggle() {
        if current == nil {
            if !queue.isEmpty {
                index = 0
                load(autoplay: true)
            }
            return
        }
        if isPlaying {
            pause()
        } else {
            // 播放结束后再次点播放，从文件开头重新开始。
            if duration > 0, elapsed >= duration - 0.25 {
                seek(to: 0)
            }
            resume()
        }
    }

    func resume() {
        guard current != nil else { return }
        guard engine.currentItem != nil else {
            load(autoplay: true)
            return
        }
        AudioSessionManager.activate()
        engine.rate = Float(speed)          // 用 rate 而不是 play()，倍速才会生效
        isPlaying = true
        resumeTimeSleepTimerIfNeeded()
        NowPlayingCenter.shared.refresh()
    }

    func pause() {
        engine.pause()
        isPlaying = false
        pauseTimeSleepTimerIfNeeded()
        if let file = current {
            let knownDuration = duration > 0 ? duration : file.duration
            PlaybackProgress.shared.record(
                file.relativePath,
                seconds: elapsed,
                duration: knownDuration,
                force: true
            )
        }
        NowPlayingCenter.shared.refresh()
    }

    private func pauseForSystemInterruption() {
        guard isPlaying else { return }
        pause()
    }

    func next() { advance(forward: true, userInitiated: true) }

    func previous() {
        guard !queue.isEmpty else { return }
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        if isShuffled, let last = history.popLast() {
            commitCurrentProgress()
            index = last
            load(autoplay: true, resumeSavedPosition: false)
            return
        }
        advance(forward: false, userInitiated: true)
    }

    func jump(to file: MusicFile) {
        guard let target = queue.firstIndex(where: { $0.id == file.id }) else { return }
        commitCurrentProgress()
        history.append(index)
        index = target
        load(autoplay: true)
    }

    func seek(to seconds: Double) {
        let target = seconds.clamped(to: 0...max(duration, 0.1))
        engine.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        elapsed = target
        NowPlayingCenter.shared.refresh()
    }

    /// 相对当前进度前进或后退。时长未知时仍允许先更新界面时间。
    func skip(by seconds: Double) {
        guard current != nil, seconds.isFinite, seconds != 0 else { return }
        let candidate = max(0, elapsed + seconds)
        if duration > 0 {
            seek(to: min(candidate, duration))
        } else {
            engine.seek(to: CMTime(seconds: candidate, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
            elapsed = candidate
            NowPlayingCenter.shared.refresh()
        }
    }

    /// 当前歌曲被「文件」App 等外部途径删掉后，清空陈旧的播放现场。
    @discardableResult
    func discardCurrentIfMissing() -> Bool {
        guard let file = current,
              !FileManager.default.fileExists(atPath: file.url.path) else {
            return false
        }

        engine.pause()
        engine.replaceCurrentItem(with: nil)
        isPlaying = false
        cancelSleepTimer()
        queue.removeAll()
        history.removeAll()
        index = -1
        elapsed = 0
        duration = 0
        brokenSkips = 0

        PlaybackProgress.shared.clear(file.relativePath)
        MetadataStore.shared.forget(file.url)
        ArtworkStore.shared.remove(key: file.relativePath)
        UserDefaults.standard.removeObject(forKey: Self.lastPathKey)
        NowPlayingCenter.shared.refresh()
        return true
    }

    func toggleShuffle() {
        isShuffled.toggle()
        history.removeAll()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    // MARK: 倍速

    /// 0.5×–2.0×，步进 0.1，会记住
    func setSpeed(_ value: Double) {
        let snapped = ((value * 10).rounded() / 10).clamped(to: 0.5...2.0)
        applySpeed(snapped)
    }

    private func applySpeed(_ value: Double) {
        guard value != speed else { return }
        speed = value
        UserDefaults.standard.set(value, forKey: "speed")
        if isPlaying { engine.rate = Float(value) }
        NowPlayingCenter.shared.refresh()
    }

    // MARK: 定时停止

    func startSleepTimer(minutes: Double) {
        sleepRemaining = max(0, minutes * 60)
        sleepTimer = .time
        sleepLastTickUptime = isPlaying ? ProcessInfo.processInfo.systemUptime : nil
        engine.volume = 1
        if isPlaying {
            startTicker()
        } else {
            stopTicker()
        }
        ToastCenter.shared.show(L10n.sleepScheduled(minutes: Int(minutes.rounded())))
    }

    func startSleepTimer(tracks: Int) {
        let count = max(1, tracks)
        stopTicker()
        sleepLastTickUptime = nil
        engine.volume = 1
        sleepTimer = .tracks(total: count, remaining: count)
        sleepRemaining = 0
        ToastCenter.shared.show(L10n.sleepScheduled(tracks: count))
    }

    func cancelSleepTimer() {
        sleepTimer = .off
        sleepRemaining = 0
        sleepLastTickUptime = nil
        engine.volume = 1
        stopTicker()
    }

    /// 主界面那个按钮：没在计时就用预设时间开始，正在计时就取消
    func togglePresetTimer() {
        if sleepTimer.isActive {
            cancelSleepTimer()
            ToastCenter.shared.show(L10n.sleepCancelled)
        } else {
            startSleepTimer(minutes: timerPresetMinutes)
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled, let self else { return }
                self.tickSleepTimer()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tickSleepTimer() {
        guard isPlaying, case .time = sleepTimer else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard let lastTick = sleepLastTickUptime else {
            sleepLastTickUptime = now
            return
        }
        let elapsed = max(0, now - lastTick)
        sleepLastTickUptime = now

        sleepRemaining = sleepRemainingAfter(
            sleepRemaining,
            elapsed: elapsed,
            isActuallyPlaying: engine.timeControlStatus == .playing
        )
        if sleepRemaining <= 0 {
            finishSleep(reason: L10n.sleepTimeElapsed)
        } else if sleepRemaining <= 5 {
            engine.volume = Float(max(0, sleepRemaining / 5))   // 最后 5 秒淡出
        }
    }

    /// 暂停播放时冻结剩余时间，继续播放时从冻结点重新计算。
    private func pauseTimeSleepTimerIfNeeded() {
        guard case .time = sleepTimer, ticker != nil else { return }
        sleepLastTickUptime = nil
        stopTicker()
        engine.volume = 1
    }

    private func resumeTimeSleepTimerIfNeeded() {
        guard case .time = sleepTimer, ticker == nil else { return }
        guard sleepRemaining > 0 else {
            finishSleep(reason: L10n.sleepTimeElapsed)
            return
        }
        sleepLastTickUptime = ProcessInfo.processInfo.systemUptime
        startTicker()
    }

    private func finishSleep(reason: String) {
        engine.pause()
        engine.volume = 1
        isPlaying = false
        commitCurrentProgress()
        sleepTimer = .off
        sleepRemaining = 0
        sleepLastTickUptime = nil
        stopTicker()
        ToastCenter.shared.show(reason)
        NowPlayingCenter.shared.refresh()
    }

    /// 播完一首之后按曲目数递减，减到 0 就停
    private func consumeTrackForSleepTimer() -> Bool {
        guard case let .tracks(total, remaining) = sleepTimer else { return false }
        let left = remaining - 1
        if left <= 0 {
            finishSleep(reason: L10n.sleepTracksElapsed(total))
            return true
        }
        sleepTimer = .tracks(total: total, remaining: left)
        return false
    }

    // MARK: 内部

    private func commitCurrentProgress() {
        guard let file = current else { return }
        let knownDuration = duration > 0 ? duration : file.duration
        PlaybackProgress.shared.record(
            file.relativePath,
            seconds: elapsed,
            duration: knownDuration,
            force: true
        )
    }

    private func advance(forward: Bool, userInitiated: Bool) {
        guard !queue.isEmpty else { return }
        commitCurrentProgress()

        if !userInitiated {
            if consumeTrackForSleepTimer() { return }
            if repeatMode == .one {
                seek(to: 0)
                engine.rate = Float(speed)
                isPlaying = true
                resumeTimeSleepTimerIfNeeded()
                NowPlayingCenter.shared.refresh()
                return
            }
        }

        guard let nextIndex = nextIndex(forward: forward) else {
            engine.pause()
            isPlaying = false
            pauseTimeSleepTimerIfNeeded()
            // 队列结束时停在最后一首的末尾，方便用户向左拖动回听，
            // 不要立刻把进度重置到 0。
            let end = duration > 0 ? duration : elapsed
            elapsed = end
            engine.seek(
                to: CMTime(seconds: end, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            NowPlayingCenter.shared.refresh()
            return
        }

        history.append(index)
        index = nextIndex
        // 顺序切到队列中的另一首时，从头播放；从列表主动选择仍可断点续播。
        load(autoplay: true, resumeSavedPosition: false)
    }

    private func nextIndex(forward: Bool) -> Int? {
        let count = queue.count
        guard count > 0 else { return nil }
        guard index >= 0, index < count else { return 0 }
        if isShuffled, forward, count > 1 {
            var pick = index
            while pick == index { pick = Int.random(in: 0..<count) }
            return pick
        }
        let candidate = forward ? index + 1 : index - 1
        if candidate >= 0, candidate < count { return candidate }
        switch repeatMode {
        case .all: return forward ? 0 : count - 1
        case .one: return forward ? (count > 1 ? 0 : index) : (count > 1 ? count - 1 : index)
        case .off: return nil
        }
    }

    private func load(autoplay: Bool, resumeSavedPosition: Bool = true) {
        guard let file = current else { return }
        let url = file.url
        guard FileManager.default.fileExists(atPath: url.path) else {
            brokenSkips += 1                       // 文件被外部删了，跳过别卡住
            if brokenSkips < queue.count, let next = nextIndex(forward: true), next != index {
                index = next
                load(
                    autoplay: autoplay,
                    resumeSavedPosition: resumeSavedPosition
                )
            } else {
                isPlaying = false
                pauseTimeSleepTimerIfNeeded()
            }
            return
        }
        brokenSkips = 0
        AudioSessionManager.activate()

        // 记住这次放的是哪首，退出后要能恢复现场
        UserDefaults.standard.set(file.relativePath, forKey: Self.lastPathKey)

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 3
        // 变速不变调：音乐用 spectral，人声（听书）可以改成 .timeDomain
        item.audioTimePitchAlgorithm = .spectral
        engine.replaceCurrentItem(with: item)

        elapsed = 0
        // 标签可能还没读完；断点记录里的时长通常已经可靠，先用它避免
        // 界面把“已恢复的秒数”误算成接近结束。
        duration = max(
            file.duration,
            PlaybackProgress.shared.duration(for: file.relativePath)
        )

        // 断点续播：这个文件听过就地接着播
        let resumeAt = resumeSavedPosition
            ? PlaybackProgress.shared.resumeStart(for: file)
            : 0
        if resumeAt > 0 {
            engine.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
            elapsed = resumeAt
        }

        if autoplay {
            engine.rate = Float(speed)
            isPlaying = true
            resumeTimeSleepTimerIfNeeded()
        }
        NowPlayingCenter.shared.refresh()
    }
}
