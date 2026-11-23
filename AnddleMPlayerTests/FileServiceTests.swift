import XCTest
@testable import AnddleMPlayer

final class FileServiceTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnddleMPlayerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    func testImportAudioPreservesStructureAndSkipsNonAudioFiles() throws {
        let source = temporaryRoot.appendingPathComponent("Album", isDirectory: true)
        let nested = source.appendingPathComponent("Live", isDirectory: true)
        let empty = source.appendingPathComponent("Empty", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("Destination", isDirectory: true)

        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try Data([0x01]).write(to: source.appendingPathComponent("01.mp3"))
        try Data([0x02]).write(to: nested.appendingPathComponent("02.m4a"))
        try Data([0x03]).write(to: source.appendingPathComponent("cover.jpg"))
        try Data([0x04]).write(to: nested.appendingPathComponent("notes.txt"))
        try Data([0x05]).write(to: empty.appendingPathComponent("readme.txt"))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let result = FileService.importAudioItems([source], into: destination)
        let imported = destination.appendingPathComponent("Album", isDirectory: true)

        XCTAssertEqual(result.importedAudio, 2)
        XCTAssertEqual(result.skippedEmptyFolders, 0)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: imported.appendingPathComponent("01.mp3").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: imported.appendingPathComponent("Live/02.m4a").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: imported.appendingPathComponent("cover.jpg").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: imported.appendingPathComponent("Live/notes.txt").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: imported.appendingPathComponent("Empty").path
        ))
    }

    func testImportingFolderWithoutAudioIsReportedAndNotCreated() throws {
        let source = temporaryRoot.appendingPathComponent("NoAudio", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("Destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data([0x01]).write(to: source.appendingPathComponent("cover.png"))

        let result = FileService.importAudioItems([source], into: destination)

        XCTAssertEqual(result.importedAudio, 0)
        XCTAssertEqual(result.skippedEmptyFolders, 1)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("NoAudio").path
        ))
    }

    func testSupportedAudioExtensionsAreCaseInsensitive() {
        XCTAssertTrue(FileService.isAudio(URL(fileURLWithPath: "/tmp/song.MP3")))
        XCTAssertTrue(FileService.isAudio(URL(fileURLWithPath: "/tmp/song.FlAc")))
        XCTAssertFalse(FileService.isAudio(URL(fileURLWithPath: "/tmp/video.mp4")))
    }
}
