import XCTest
@testable import AnddleMPlayer

final class LibraryPathsTests: XCTestCase {
    func testBootstrapCreatesPlayablePreviewAudio() {
        LibraryPaths.bootstrap()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: LibraryPaths.root.path,
            isDirectory: &isDirectory
        ))
        XCTAssertTrue(isDirectory.boolValue)

        let preview = LibraryPaths.previewAudio
        XCTAssertTrue(FileManager.default.fileExists(atPath: preview.path))
        XCTAssertTrue(FileService.isAudio(preview))
        XCTAssertTrue(
            FileService.audioURLs(in: LibraryPaths.root)
                .contains { $0.standardizedFileURL == preview.standardizedFileURL },
            "试听音乐必须作为普通音频出现在 App 列表中"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: LibraryPaths.root
                    .appendingPathComponent("AnddleMusicPlayer_Keep.txt")
                    .path
            )
        )
    }

    func testPreviewRestoresOnlyWhenVisibleLibraryIsEmpty() {
        XCTAssertTrue(LibraryPaths.shouldRestorePreview(visibleNames: []))
        XCTAssertTrue(
            LibraryPaths.shouldRestorePreview(
                visibleNames: [".hidden", LibraryPaths.previewAudioName]
            )
        )
        XCTAssertFalse(
            LibraryPaths.shouldRestorePreview(visibleNames: ["另一些音乐.mp3"])
        )
        XCTAssertFalse(
            LibraryPaths.shouldRestorePreview(visibleNames: ["某个文件夹"])
        )
    }
}
