import SwiftUI

/// 整屏播放页：背景由封面派生，控件全部压在屏幕下三分之一。
struct NowPlayingView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.dismiss) private var dismiss
    var onClose: () -> Void = {}

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showSettings = false
    @State private var showQueue = false
    @State private var showSpeedPopover = false
    @State private var showThemePicker = false

    var body: some View {
        GeometryReader { geo in
            let artSide = safeArtworkSide(in: geo.size)
            ZStack {
                background
                VStack(spacing: 0) {
                    topBar

                    Spacer(minLength: 8)
                    artwork(side: artSide)
                    Spacer(minLength: 18)
                    titles
                    quickActions.padding(.top, 20)
                    progressSection.padding(.top, 14)
                    controls.padding(.top, 16)
                    Spacer(minLength: 10)
                }
                .padding(.horizontal, 26)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background {
            TwoFingerTapCaptureView {
                player.skip(by: Double(appState.twoFingerForwardSeconds))
            }
        }
        .sheet(isPresented: $showSettings) { PlaybackSettingsSheet() }
        .sheet(isPresented: $showQueue) { QueueSheet() }
        .onAppear { scrubValue = player.elapsed }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            themeOption(.red, title: L10n.key("红黑·经典配色"))
            themeOption(.amber, title: L10n.key("琥珀·暖色影院"))
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(6)
        .background(Palette.surface)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Palette.surface)
    }

    private func themeOption(_ theme: PlayerColorTheme, title: String) -> some View {
        let selected = appearance.theme == theme
        return Button {
            appearance.select(theme)
            showThemePicker = false
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(selected ? theme.accent : Color.clear)
                    .overlay {
                        Circle()
                            .strokeBorder(theme.accent, lineWidth: 1.5)
                    }
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.text : Palette.sub)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 顶部：中间是抓手，左边是收起按钮，整条都能下滑关闭。
    /// 全屏之后没有系统自带的拖拽关闭，得自己给一个出口。
    private var topBar: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 38, height: 5)
            HStack {
                Button {
                    close()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起播放界面")
                Spacer()
                Button {
                    showThemePicker = true
                } label: {
                    Circle()
                        .fill(appearance.accent)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.38), lineWidth: 0.8)
                        }
                        .shadow(color: appearance.accent.opacity(0.38), radius: 3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.key("切换配色"))
                .popover(isPresented: $showThemePicker, arrowEdge: .top) {
                    themePicker
                }
                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("接下来播放")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放设置")
            }
        }
        .frame(height: 44)
        .padding(.top, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 60 { close() }
            }
        )
    }

    // MARK: 背景

    private var background: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                RadialGradient(
                    colors: [
                        appearance.accent.opacity(0.14),
                        appearance.accent.opacity(0.025),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.27),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.62
                )
                if let image = ArtworkStore.shared.image(for: player.current?.artworkKey) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 56)
                        .scaleEffect(1.18)
                        // 封面只留极淡的氛围，主体交给留白唱片。
                        .saturation(0.34)
                        .opacity(0.10)
                }
                LinearGradient(
                    colors: [
                        .black.opacity(0.24), .black.opacity(0.40),
                        .black.opacity(0.77), .black.opacity(0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: 封面与手势

    private func safeArtworkSide(in size: CGSize) -> CGFloat {
        let availableWidth = size.width.isFinite ? max(1, size.width - 56) : 400
        let availableHeight = size.height.isFinite ? max(1, size.height * 0.44) : 400
        return max(1, min(availableWidth, availableHeight, 400))
    }

    private func artwork(side: CGFloat) -> some View {
        VinylView(file: player.current)
            .frame(width: side, height: side)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.3
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { dragOffset = 0 }
                        if abs(dx) > 60, abs(dx) >= abs(dy) {
                            let seconds = Double(appState.swipeSeekSeconds)
                            player.skip(by: dx < 0 ? -seconds : seconds)
                        } else if abs(dy) > 70, abs(dy) > abs(dx) {
                            player.setSpeed(dy < 0 ? 1.5 : 1.0)
                        }
                    }
            )
            .onTapGesture { player.toggle() }
    }

    private var titles: some View {
        Text(fileNameForNaturalWrapping(playbackFileName))
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Palette.text)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .lineLimit(3)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var playbackFileName: String {
        guard let name = player.current?.name else { return L10n.key("暂无播放内容") }
        let baseName = (name as NSString).deletingPathExtension
        return baseName.isEmpty ? name : baseName
    }

    // MARK: 进度

    private var displayedElapsed: Double {
        isScrubbing ? scrubValue : player.elapsed
    }

    private var timelineDuration: Double {
        if player.duration > 0 { return player.duration }
        if let path = player.current?.relativePath {
            let recorded = PlaybackProgress.shared.duration(for: path)
            if recorded > 0 { return recorded }
        }
        return 0
    }

    private var displayedProgress: Double {
        timelineDuration > 0 ? displayedElapsed : 0
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            ThinSlider(
                value: Binding(get: { displayedProgress }, set: { scrubValue = $0 }),
                // 这里传的是「秒」，必须把量程也告诉滑杆 ——
                // 默认量程是 0…1，秒数进来会被截断成 1，进度条一开播就满格
                range: 0...max(timelineDuration, 0.1),
                trackColor: Color.white.opacity(0.14),
                fillColor: appearance.accent,
                thickness: 1
            ) { editing in
                if editing {
                    scrubValue = player.elapsed
                    isScrubbing = true
                    player.isScrubbing = true
                } else {
                    player.isScrubbing = false
                    player.seek(to: scrubValue)
                    isScrubbing = false
                }
            }
            // 第一行是文件本身的时间（正常速度下的时间轴）
            HStack {
                Text(fmtTime(displayedElapsed))
                Spacer()
                Text(remainingLabel)
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(isNormalSpeed ? Palette.faint : Palette.faint.opacity(0.72))

            // 变速时显示按当前倍速折算的实际用时。
            // 这一行在正常速度下也占据同样高度，避免变速时整个播放界面上下跳动。
            HStack(spacing: 6) {
                Text(fmtTime(displayedElapsed / player.speed))
                Spacer()
                Text(remainingAtSpeedLabel)
            }
            .font(.system(size: 10.5))
            .monospacedDigit()
            .foregroundStyle(Palette.text.opacity(0.82))
            .frame(height: 13)
            .opacity(isNormalSpeed ? 0 : 1)
            .accessibilityHidden(isNormalSpeed)
        }
    }

    private var isNormalSpeed: Bool { abs(player.speed - 1.0) < 0.001 }

    private var remainingLabel: String {
        guard timelineDuration > 0 else { return "-0:00" }
        return "-" + fmtTime(max(0, timelineDuration - displayedElapsed))
    }

    /// 剩余还要多久（按当前倍速折算）
    private var remainingAtSpeedLabel: String {
        guard timelineDuration > 0, player.speed > 0 else { return "-0:00" }
        return "-" + fmtTime(max(0, timelineDuration - displayedElapsed) / player.speed)
    }

    // MARK: 控制

    private var controls: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundStyle(player.isShuffled ? appearance.accent : Palette.faint)
            }
            Spacer(minLength: 0)

            Button { player.previous() } label: {
                Image(systemName: "backward.end")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Palette.text)
            }
            Spacer(minLength: 0)

            Button { player.toggle() } label: {
                ZStack {
                    Circle().fill(appearance.accent).frame(width: 64, height: 64)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Palette.accentInk)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
                .shadow(color: appearance.accent.opacity(0.24), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.38), radius: 12, y: 7)
            }
            Spacer(minLength: 0)

            Button { player.next() } label: {
                Image(systemName: "forward.end")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Palette.text)
            }
            Spacer(minLength: 0)

            Button { player.cycleRepeatMode() } label: {
                Image(systemName: player.repeatMode.symbolName)
                    .font(.system(size: 18))
                    .foregroundStyle(player.repeatMode.isActive ? appearance.accent : Palette.faint)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 进度条上方：倒计时 / 播放速度

    /// 音量不在这里 —— 音量键和控制中心直接管，App 不插手
    private var quickActions: some View {
        HStack(spacing: 12) {
            // 一键倒计时：没在计时就按预设时间开始，正在计时就取消
            Button {
                player.togglePresetTimer()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: player.sleepTimer.isActive ? "moon.fill" : "moon")
                        .font(.system(size: 11))
                    Text(timerLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(player.sleepTimer.isActive ? appearance.accent : Palette.sub)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(
                    player.sleepTimer.isActive ? appearance.accent.opacity(0.16) : Palette.fill,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.sleepTimer.isActive ? L10n.cancelTimer : L10n.startTimer)

            Spacer(minLength: 12)

            Button {
                showSpeedPopover = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 12, weight: .medium))
                    Text(speedLabel)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(player.speed == 1.0 ? Palette.sub : appearance.accent)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(Palette.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.speedAccessibility(speedLabel))
            .popover(isPresented: $showSpeedPopover, arrowEdge: .bottom) {
                speedPopover
            }
        }
    }

    private var speedLabel: String {
        String(format: "%.2f×", locale: .current, player.speed)
    }

    private var speedPopover: some View {
        HStack(spacing: 16) {
            speedStepButton(
                symbol: "minus",
                delta: -0.1,
                disabled: player.speed <= 0.501
            )

            Text(speedLabel)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.text)
                .frame(minWidth: 86)

            speedStepButton(
                symbol: "plus",
                delta: 0.1,
                disabled: player.speed >= 1.999
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Palette.line, lineWidth: 0.5)
        }
        .padding(8)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Palette.surface)
    }

    private func speedStepButton(symbol: String, delta: Double, disabled: Bool) -> some View {
        Button {
            player.setSpeed(player.speed + delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.accentInk)
                .frame(width: 38, height: 38)
                .background(Color.white, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.28 : 1)
    }

    /// 没在计时时显示预设时间，计时中显示剩余量
    private var timerLabel: String {
        switch player.sleepTimer {
        case .off:
            let totalSeconds = Int((player.timerPresetMinutes * 60).rounded())
            return L10n.compactTimer(
                minutes: totalSeconds / 60,
                seconds: totalSeconds % 60
            )
        case .time:
            let totalSeconds = Int(max(0, player.sleepRemaining).rounded(.up))
            return L10n.compactTimer(
                minutes: totalSeconds / 60,
                seconds: totalSeconds % 60
            )
        case let .tracks(_, remaining):
            return L10n.tracks(remaining)
        }
    }

    private func close() {
        onClose()
        dismiss()
    }

}
