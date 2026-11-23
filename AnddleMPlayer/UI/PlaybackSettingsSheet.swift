import SwiftUI

/// 播放设置：只处理定时停止；倍速统一从进度条上方的弹出调节器修改。
struct PlaybackSettingsSheet: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    @State private var chosenMinutes: Int?
    @State private var chosenTracks: Int?
    @State private var showCustomMinutes = false
    @State private var customMinutes = ""
    @State private var showCustomTracks = false
    @State private var customTracks = ""
    @State private var showCustomSwipeSeconds = false
    @State private var customSwipeSeconds = ""
    @State private var showCustomForwardSeconds = false
    @State private var customForwardSeconds = ""
    @State private var showAbout = false

    private let minuteOptions = [15, 30, 60]
    private let trackOptions = [1, 2, 3]
    private let swipeOptions = [5, 10, 15, 30]
    private let forwardOptions = [10, 30, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 18)

                Text("播放设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)

                if let status = timerStatus {
                    Text(status)
                        .font(.system(size: 12.5))
                        .monospacedDigit()
                        .foregroundStyle(appearance.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }

                sectionHead("按时间停止", actionTitle: "自定义…") {
                    customMinutes = ""
                    showCustomMinutes = true
                }
                HStack(spacing: 6) {
                    ForEach(minuteOptions, id: \.self) { minutes in
                        ChipButton(title: L10n.minutes(minutes), isOn: chosenMinutes == minutes) {
                            chosenMinutes = minutes
                            chosenTracks = nil
                            player.timerPresetMinutes = Double(minutes)
                        }
                    }
                }

                Text("这里只更新预设；点击播放页上的倒计时按钮后才会开始。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .padding(.top, 7)

                sectionHead("按曲目播完", actionTitle: "其他数量…") {
                    customTracks = ""
                    showCustomTracks = true
                }
                HStack(spacing: 6) {
                    ForEach(trackOptions, id: \.self) { count in
                        ChipButton(title: L10n.tracks(count), isOn: chosenTracks == count) {
                            chosenTracks = count
                            chosenMinutes = nil
                            player.startSleepTimer(tracks: count)
                        }
                    }
                }

                if player.sleepTimer.isActive {
                    Button {
                        player.cancelSleepTimer()
                        chosenMinutes = nil
                        chosenTracks = nil
                    } label: {
                        Text("取消定时")
                            .font(.system(size: 14))
                            .foregroundStyle(appearance.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                    }
                    .buttonStyle(.plain)
                }

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)
                    .padding(.top, 22)

                Text("手势跳转")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 18)

                Text("向左滑动倒退，向右滑动前进；双指单击向前跳转。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.faint)
                    .padding(.top, 5)

                sectionHead("左右滑动", actionTitle: "自定义…") {
                    customSwipeSeconds = "\(appState.swipeSeekSeconds)"
                    showCustomSwipeSeconds = true
                }
                HStack(spacing: 6) {
                    ForEach(swipeOptions, id: \.self) { seconds in
                        ChipButton(
                            title: L10n.compactSeconds(seconds),
                            isOn: appState.swipeSeekSeconds == seconds
                        ) {
                            appState.swipeSeekSeconds = seconds
                        }
                    }
                }

                sectionHead("双指点击前进", actionTitle: "自定义…") {
                    customForwardSeconds = "\(appState.twoFingerForwardSeconds)"
                    showCustomForwardSeconds = true
                }
                HStack(spacing: 6) {
                    ForEach(forwardOptions, id: \.self) { seconds in
                        ChipButton(
                            title: L10n.compactSeconds(seconds),
                            isOn: appState.twoFingerForwardSeconds == seconds
                        ) {
                            appState.twoFingerForwardSeconds = seconds
                        }
                    }
                }

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)
                    .padding(.top, 22)

                Button {
                    showAbout = true
                } label: {
                    HStack(spacing: 12) {
                        Text("关于")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)

                        Spacer()

                        Text(L10n.version(marketingVersion))
                            .font(.system(size: 12.5))
                            .monospacedDigit()
                            .foregroundStyle(Palette.faint)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.faint)
                    }
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .background(Palette.surface)
        .presentationDetents([.height(640), .large])
        .presentationBackground(Palette.surface)
        .alert("自定义分钟数", isPresented: $showCustomMinutes) {
            TextField("分钟", text: $customMinutes).keyboardType(.numberPad)
            Button("开始") {
                if let value = Double(customMinutes), value > 0 {
                    chosenMinutes = Int(value)
                    chosenTracks = nil
                    player.timerPresetMinutes = value
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("自定义曲目数", isPresented: $showCustomTracks) {
            TextField("首数", text: $customTracks).keyboardType(.numberPad)
            Button("开始") {
                if let value = Int(customTracks), value > 0 {
                    chosenTracks = value
                    chosenMinutes = nil
                    player.startSleepTimer(tracks: value)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("左右滑动秒数", isPresented: $showCustomSwipeSeconds) {
            TextField("秒", text: $customSwipeSeconds).keyboardType(.numberPad)
            Button("确定") {
                if let value = Int(customSwipeSeconds), value > 0 {
                    appState.swipeSeekSeconds = min(value, 600)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("双指点击前进秒数", isPresented: $showCustomForwardSeconds) {
            TextField("秒", text: $customForwardSeconds).keyboardType(.numberPad)
            Button("确定") {
                if let value = Int(customForwardSeconds), value > 0 {
                    appState.twoFingerForwardSeconds = min(value, 600)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert(L10n.about(appName), isPresented: $showAbout) {
            Button("好") {}
        } message: {
            Text(L10n.version(versionDescription))
        }
    }

    // MARK: 部件

    private func sectionHead(_ title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.sub)
            Spacer()
            Button(LocalizedStringKey(actionTitle), action: action)
                .font(.system(size: 12.5))
                .foregroundStyle(appearance.accent)
                .buttonStyle(.plain)
        }
        .padding(.top, 20)
        .padding(.bottom, 9)
    }

    private var timerStatus: String? {
        switch player.sleepTimer {
        case .off:
            return nil
        case .time:
            let totalSeconds = Int(max(0, player.sleepRemaining).rounded(.up))
            return L10n.compactTimer(
                minutes: totalSeconds / 60,
                seconds: totalSeconds % 60
            )
        case let .tracks(_, remaining):
            return L10n.remainingTracks(remaining)
        }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "AnddleMPlayer"
    }

    private var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? L10n.unknown
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? ""
    }

    private var versionDescription: String {
        buildVersion.isEmpty
            ? marketingVersion
            : "\(marketingVersion) (\(buildVersion))"
    }
}

/// 选项胶囊
struct ChipButton: View {
    @Environment(AppearanceStore.self) private var appearance
    var title: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Palette.accentInk : Palette.sub)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isOn ? appearance.accent : Palette.fill)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
