import SwiftUI

/// 极细的滑杆：进度条和音量条共用。
/// `onEditingChanged(true)` 表示开始拖动，用来告诉播放器「先别用时钟回调覆盖我」。
struct ThinSlider: View {
    @Binding var value: Double
    /// 量程。刻意不给默认值 —— 传进来的 value 是秒还是比例，必须由调用方明说，
    /// 否则秒数会被当成比例截断成 1，进度条一开播就满格。
    var range: ClosedRange<Double>
    var trackColor: Color = .white.opacity(0.22)
    var fillColor: Color = .white
    var knobColor: Color = .white
    var thickness: CGFloat = 4
    var showsKnob: Bool = true
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let ratio = normalized(value)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .frame(width: width, height: thickness)
                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: width * ratio, height: thickness)
                if showsKnob {
                    let knobSize: CGFloat = 10
                    let knobOffset = (width * ratio - knobSize / 2)
                        .clamped(to: 0...max(0, width - knobSize))
                    Circle()
                        .fill(knobColor)
                        .frame(width: knobSize, height: knobSize)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.5)
                        }
                        .scaleEffect(isDragging ? 1.25 : 1)
                        .shadow(color: fillColor.opacity(0.32), radius: isDragging ? 4 : 2)
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                        .offset(x: knobOffset)
                        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isDragging)
                }
            }
            .frame(width: width, height: 22, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = valueFor(x: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        value = valueFor(x: gesture.location.x, width: width)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 22)
    }

    private func normalized(_ raw: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return ((raw - range.lowerBound) / span).clamped(to: 0...1)
    }

    private func valueFor(x: CGFloat, width: CGFloat) -> Double {
        let ratio = Double((x / width).clamped(to: 0...1))
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + ratio * span
    }
}
