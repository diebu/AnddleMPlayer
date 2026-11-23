import SwiftUI
import UIKit

/// SwiftUI 没有公开双指点击手势，这里挂一个不拦截触摸的 UIKit 识别器。
struct TwoFingerTapCaptureView: UIViewRepresentable {
    var action: () -> Void

    func makeUIView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.action = action
        return view
    }

    func updateUIView(_ uiView: CaptureView, context: Context) {
        uiView.action = action
    }

    static func dismantleUIView(_ uiView: CaptureView, coordinator: ()) {
        uiView.detach()
    }

    final class CaptureView: UIView {
        var action: (() -> Void)?
        private weak var gestureWindow: UIWindow?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.numberOfTouchesRequired = 2
            recognizer.numberOfTapsRequired = 1
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesEnded = false
            return recognizer
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard gestureWindow !== window else { return }
            detach()
            guard let window else { return }
            gestureWindow = window
            window.addGestureRecognizer(recognizer)
        }

        func detach() {
            gestureWindow?.removeGestureRecognizer(recognizer)
            gestureWindow = nil
        }

        @objc private func handleTap() {
            action?()
        }
    }
}
