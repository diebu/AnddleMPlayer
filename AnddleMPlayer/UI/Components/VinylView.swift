import SwiftUI

/// 带唱臂的双色黑胶唱片。盘面与文件夹标签旋转，唱臂和反光保持固定。
///
/// 盘心直接显示当前歌曲所在文件夹名称，
/// 让播放页更像一台简洁的桌面唱机。
struct VinylView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppearanceStore.self) private var appearance
    var file: MusicFile?
    /// 每秒转多少度，约 26 秒一圈
    var degreesPerSecond: Double = 14

    @State private var rotationAnchorDate = Date()
    @State private var rotationAnchorAngle: Double = 0

    private var folderName: String {
        file?.containingFolderName ?? L10n.music
    }

    private var readingProgress: CGFloat {
        let duration = player.duration > 0 ? player.duration : (file?.duration ?? 0)
        guard duration > 0 else { return 0 }
        return CGFloat((player.elapsed / duration).clamped(to: 0...1))
    }

    private var headColor: Color {
        appearance.theme == .amber
            ? Color(red: 0.075, green: 0.043, blue: 0.010)
            : Color(red: 0.075, green: 0.025, blue: 0.045)
    }

    private var pivotColor: Color {
        appearance.theme == .amber
            ? Color(red: 0.11, green: 0.063, blue: 0.014)
            : Color(red: 0.11, green: 0.035, blue: 0.065)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let discSide = side * 0.92
            let labelSide = discSide * 0.64
            let discCenter = CGPoint(x: side * 0.5, y: side * 0.53)

            ZStack {
                ZStack {
                    TimelineView(
                        .animation(
                            minimumInterval: 1.0 / 60.0,
                            paused: !player.isPlaying || player.isScrubbing
                        )
                    ) { timeline in
                        ZStack {
                            recordBody
                            grooves(labelSide: labelSide)
                            label(labelSide: labelSide)
                        }
                        .drawingGroup()
                        .clipShape(Circle())
                        .rotationEffect(.degrees(rotation(at: timeline.date)))
                    }
                }
                .frame(width: discSide, height: discSide)
                .position(discCenter)

                tonearm(side: side)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { alignRotationToPlayback() }
        .onChange(of: player.isPlaying) { wasPlaying, isPlaying in
            if wasPlaying, !isPlaying {
                freezeRotation()
            } else {
                rotationAnchorDate = Date()
            }
        }
        .onChange(of: player.isScrubbing) { wasScrubbing, isScrubbing in
            if !wasScrubbing, isScrubbing {
                freezeRotation()
            } else if wasScrubbing, !isScrubbing {
                // 跳转后保持拖动前的唱片角度，避免追着新进度快速旋转。
                rotationAnchorDate = Date()
            }
        }
        .onChange(of: player.speed) { _, _ in
            // 保留当前角度，从这一刻开始按新速度继续转。
            rotationAnchorDate = Date()
        }
        .onChange(of: file?.id) { _, _ in alignRotationToPlayback() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, player.isPlaying, !player.isScrubbing {
                rotationAnchorDate = Date()
            }
        }
    }

    private var recordBody: some View {
        Circle()
            .fill(appearance.accent)
    }

    /// 纯色盘面上的同心沟槽，线条刻意加粗以便远看也能辨认。
    private func grooves(labelSide: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) * 0.486
            var radius = labelSide * 0.59

            while radius < outer {
                let ring = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: ring),
                    with: .color(.black.opacity(0.28)),
                    lineWidth: 1.6
                )
                radius += 3.4
            }
        }
        .allowsHitTesting(false)
    }

    private func label(labelSide: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: labelSide, height: labelSide)

            VStack(spacing: labelSide * 0.065) {
                Text(balancedFileNameLines(folderName))
                    .font(.system(size: labelSide * 0.29, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .lineSpacing(0)
                    .minimumScaleFactor(0.24)
                    .allowsTightening(true)
                    .frame(
                        width: labelSide * 0.76,
                        height: labelSide * 0.64
                    )

                Capsule()
                    .fill(Color.white.opacity(0.48))
                    .frame(width: labelSide * 0.20, height: 1.5)
            }
        }
    }

    /// 边缘转轴、连续白色弯臂和深色唱头，组成参考图里的唱针形态。
    /// 唱臂只做视觉提示，不拦截唱片的滑动、轻点和暂停手势。
    private func tonearm(side: CGFloat) -> some View {
        let progress = readingProgress
        let pivot = CGPoint(x: side * 0.70, y: side * 0.12)

        // 从外圈向右下，再沿唱片弧面向内圈收拢；转轴不动。
        let angle = (-38 - 32 * progress) * .pi / 180
        let radius = side * (0.406 - 0.064 * progress)
        let head = CGPoint(
            x: side * 0.50 + cos(angle) * radius,
            y: side * 0.53 + sin(angle) * radius
        )
        let dx = head.x - pivot.x
        let dy = head.y - pivot.y
        let control1 = CGPoint(
            x: pivot.x + dx * 0.36,
            y: pivot.y + dy * 0.12
        )
        let control2 = CGPoint(
            x: pivot.x + dx * 0.78,
            y: pivot.y + dy * 0.64
        )
        let headLength = side * (0.060 - 0.018 * progress)
        let headRotation = 112.0

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.42))
                .frame(width: side * 0.10, height: side * 0.10)
                .blur(radius: side * 0.015)
                .position(pivot)

            tonearmPath(
                pivot: pivot,
                control1: control1,
                control2: control2,
                head: head
            )
                .stroke(
                    Color.black.opacity(0.72),
                    style: StrokeStyle(lineWidth: side * 0.026, lineCap: .round)
                )

            tonearmPath(
                pivot: pivot,
                control1: control1,
                control2: control2,
                head: head
            )
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color.white.opacity(0.76)],
                        startPoint: UnitPoint(x: pivot.x / side, y: pivot.y / side),
                        endPoint: UnitPoint(x: head.x / side, y: head.y / side)
                    ),
                    style: StrokeStyle(lineWidth: side * 0.012, lineCap: .round)
                )
                .shadow(color: .black.opacity(0.45), radius: 3, y: 2)

            Capsule()
                .fill(headColor)
                .frame(width: headLength, height: side * 0.022)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                }
                .rotationEffect(.degrees(headRotation))
                .position(head)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 2)

            Capsule()
                .fill(Color.white.opacity(0.88))
                .frame(width: headLength * 0.44, height: side * 0.005)
                .rotationEffect(.degrees(headRotation))
                .position(x: head.x - side * 0.012, y: head.y + side * 0.011)

            Circle()
                .fill(pivotColor)
                .frame(width: side * 0.064, height: side * 0.064)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
                }
                .position(pivot)

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: side * 0.043, height: side * 0.043)
                .overlay {
                    Circle()
                        .fill(appearance.accent.opacity(0.75))
                        .frame(width: side * 0.009, height: side * 0.009)
                }
                .position(pivot)
                .shadow(color: .black.opacity(0.42), radius: 2, y: 1)
        }
        .allowsHitTesting(false)
    }

    private func tonearmPath(
        pivot: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        head: CGPoint
    ) -> Path {
        var path = Path()
        path.move(to: pivot)
        path.addCurve(to: head, control1: control1, control2: control2)
        return path
    }

    /// 唱片使用独立旋转时钟，不再跟随进度跳转。
    /// 暂停或拖动进度条时冻结，继续播放后从当前角度接着转。
    private func rotation(at date: Date) -> Double {
        let angle: Double
        if player.isPlaying, !player.isScrubbing {
            let interval = max(0, date.timeIntervalSince(rotationAnchorDate))
            angle = rotationAnchorAngle + interval * degreesPerSecond * player.speed
        } else {
            angle = rotationAnchorAngle
        }
        return angle.truncatingRemainder(dividingBy: 360)
    }

    private func alignRotationToPlayback() {
        rotationAnchorAngle = player.elapsed * degreesPerSecond
        rotationAnchorDate = Date()
    }

    private func freezeRotation() {
        let now = Date()
        let interval = max(0, now.timeIntervalSince(rotationAnchorDate))
        rotationAnchorAngle += interval * degreesPerSecond * player.speed
        rotationAnchorDate = now
    }
}
