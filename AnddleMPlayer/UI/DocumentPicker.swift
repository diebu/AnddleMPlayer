import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 弹出系统文件选择器，从其他 App 的 Documents 导入本地文件或文件夹。
@MainActor
final class DocumentPickerPresenter: NSObject, UIDocumentPickerDelegate {
    private var onPick: (([URL]) -> Void)?
    private var onCancel: (() -> Void)?
    private var initialDirectory: URL?
    private var initialDirectoryHasSecurityScope = false

    func present(
        contentTypes: [UTType],
        allowsMultipleSelection: Bool,
        initialDirectory: URL?,
        onPick: @escaping ([URL]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onPick = onPick
        self.onCancel = onCancel

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: false
        )
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.shouldShowFileExtensions = true
        if let initialDirectory {
            self.initialDirectory = initialDirectory
            initialDirectoryHasSecurityScope =
                initialDirectory.startAccessingSecurityScopedResource()
            picker.directoryURL = initialDirectory
        } else {
            // 没有历史目录时打开“我的 iPhone/Downloads”。
            picker.directoryURL = URL.downloadsDirectory
        }
        picker.delegate = self

        guard let host = Self.topViewController() else {
            finishCancel()
            return
        }
        host.present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        let callback = onPick
        if let directory = urls.first?.deletingLastPathComponent() {
            RecentImportDirectory.save(directory)
        }
        clear()
        callback?(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishCancel()
    }

    private func finishCancel() {
        let callback = onCancel
        clear()
        callback?()
    }

    private func clear() {
        onPick = nil
        onCancel = nil
        if initialDirectoryHasSecurityScope, let initialDirectory {
            initialDirectory.stopAccessingSecurityScopedResource()
        }
        initialDirectory = nil
        initialDirectoryHasSecurityScope = false
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
