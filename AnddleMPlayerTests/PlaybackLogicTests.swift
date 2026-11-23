import XCTest
@testable import AnddleMPlayer

@MainActor
final class PlaybackLogicTests: XCTestCase {
    func testResumeTargetAvoidsStartAndNearEnd() {
        XCTAssertEqual(resumeTarget(saved: 0, duration: 180), 0)
        XCTAssertEqual(resumeTarget(saved: 3, duration: 180), 0)
        XCTAssertEqual(resumeTarget(saved: 42, duration: 180), 42)
        XCTAssertEqual(resumeTarget(saved: 177, duration: 180), 0)
        XCTAssertEqual(resumeTarget(saved: 42, duration: 0), 42)
    }

    func testPlaybackFractionIsClamped() {
        XCTAssertEqual(
            PlaybackPosition(seconds: 45, duration: 180).fraction,
            0.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(PlaybackPosition(seconds: -10, duration: 180).fraction, 0)
        XCTAssertEqual(PlaybackPosition(seconds: 200, duration: 180).fraction, 1)
        XCTAssertEqual(PlaybackPosition(seconds: 10, duration: 0).fraction, 0)
    }

    func testSleepTimerStateReportsCountsAndActivity() {
        let tracks = SleepTimerState.tracks(total: 5, remaining: 3)
        XCTAssertTrue(tracks.isActive)
        XCTAssertEqual(tracks.totalTracks, 5)
        XCTAssertEqual(tracks.remainingTracks, 3)

        XCTAssertFalse(SleepTimerState.off.isActive)
        XCTAssertEqual(SleepTimerState.off.totalTracks, 0)
        XCTAssertTrue(SleepTimerState.time.isActive)
    }

    func testSleepCountdownIgnoresTimeWhenEngineIsNotPlaying() {
        XCTAssertEqual(
            sleepRemainingAfter(300, elapsed: 12, isActuallyPlaying: false),
            300
        )
        XCTAssertEqual(
            sleepRemainingAfter(300, elapsed: 12, isActuallyPlaying: true),
            288
        )
        XCTAssertEqual(
            sleepRemainingAfter(5, elapsed: 12, isActuallyPlaying: true),
            0
        )
    }

    func testRepeatModeCyclesWithoutSkipping() {
        XCTAssertEqual(RepeatMode.off.next, .all)
        XCTAssertEqual(RepeatMode.all.next, .one)
        XCTAssertEqual(RepeatMode.one.next, .off)
    }

    func testSwitchingFilesCommitsPreviousProgress() throws {
        let first = try makePlayableFixture(named: "first")
        let second = try makePlayableFixture(named: "second")
        defer {
            try? FileManager.default.removeItem(at: first.url)
            try? FileManager.default.removeItem(at: second.url)
            PlaybackProgress.shared.clear(first.file.relativePath)
            PlaybackProgress.shared.clear(second.file.relativePath)
            UserDefaults.standard.removeObject(forKey: "lastPlayedPath")
        }

        let player = AudioPlayer()
        player.play(first.file, in: [first.file, second.file])
        player.elapsed = 42
        player.duration = 180

        player.play(second.file, in: [first.file, second.file])

        XCTAssertEqual(
            PlaybackProgress.shared.position(for: first.file.relativePath),
            42,
            accuracy: 0.001,
            "切换到另一个文件前，必须强制保存上一文件的最终进度"
        )
        XCTAssertEqual(
            PlaybackProgress.shared.resumeStart(for: first.file),
            42,
            accuracy: 0.001
        )
    }

    func testNextTrackStartsFromBeginningDespiteSavedProgress() throws {
        let first = try makePlayableFixture(named: "next-first")
        let second = try makePlayableFixture(named: "next-second")
        defer { cleanup(first, second) }

        PlaybackProgress.shared.record(
            second.file.relativePath,
            seconds: 42,
            duration: 180,
            force: true
        )

        let player = AudioPlayer()
        player.play(first.file, in: [first.file, second.file])
        player.next()

        XCTAssertEqual(player.current?.id, second.file.id)
        XCTAssertEqual(
            player.elapsed,
            0,
            accuracy: 0.001,
            "顺序切到下一首时必须从头播放，不能使用该文件的历史进度"
        )
    }

    func testExplicitSelectionStillResumesSavedProgress() throws {
        let first = try makePlayableFixture(named: "select-first")
        let second = try makePlayableFixture(named: "select-second")
        defer { cleanup(first, second) }

        PlaybackProgress.shared.record(
            second.file.relativePath,
            seconds: 42,
            duration: 180,
            force: true
        )

        let player = AudioPlayer()
        player.play(second.file, in: [first.file, second.file])

        XCTAssertEqual(
            player.elapsed,
            42,
            accuracy: 0.001,
            "从列表主动选择文件时仍应断点续播"
        )
    }

    func testProgressFractionFallsBackToKnownFileDuration() {
        let path = "fallback-duration-\(UUID().uuidString).mp3"
        defer { PlaybackProgress.shared.clear(path) }
        let file = MusicFile(relativePath: path, name: "chapter.mp3", duration: 180)

        PlaybackProgress.shared.record(
            path,
            seconds: 42,
            duration: 0,
            force: true
        )

        XCTAssertEqual(
            PlaybackProgress.shared.fraction(for: file),
            42.0 / 180.0,
            accuracy: 0.0001,
            "保存进度时时长未知，列表仍应使用文件已知时长计算进度条"
        )
    }

    func testPlaybackProgressPersistsAfterFlush() throws {
        let path = "persist-progress-\(UUID().uuidString).mp3"
        defer { PlaybackProgress.shared.clear(path) }

        PlaybackProgress.shared.record(
            path,
            seconds: 73,
            duration: 240,
            force: true
        )

        let data = try XCTUnwrap(
            UserDefaults.standard.data(forKey: "playbackPositions")
        )
        let saved = try JSONDecoder().decode(
            [String: PlaybackPosition].self,
            from: data
        )
        XCTAssertEqual(saved[path]?.seconds, 73)
        XCTAssertEqual(saved[path]?.duration, 240)
    }

    func testDeletingFolderClearsOnlyItsOwnProgress() async throws {
        let root = LibraryPaths.root
        let folder = root.appendingPathComponent(
            "delete-progress-\(UUID().uuidString)",
            isDirectory: true
        )
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        let other = root.appendingPathComponent(
            "keep-progress-\(UUID().uuidString).mp3"
        )
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data([0x01]).write(to: folder.appendingPathComponent("one.mp3"))
        try Data([0x02]).write(to: nested.appendingPathComponent("two.mp3"))
        try Data([0x03]).write(to: other)
        defer {
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.removeItem(at: other)
            PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: folder))
            PlaybackProgress.shared.clearDescendants(of: LibraryPaths.relativePath(of: folder))
            PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: other))
        }

        let folderPath = LibraryPaths.relativePath(of: folder)
        let onePath = folderPath + "/one.mp3"
        let twoPath = folderPath + "/nested/two.mp3"
        let otherPath = LibraryPaths.relativePath(of: other)
        for path in [onePath, twoPath, otherPath] {
            PlaybackProgress.shared.record(
                path,
                seconds: 30,
                duration: 180,
                force: true
            )
        }

        let model = DirectoryModel(directory: root, isRoot: true)
        let deleted = await model.delete([folder])

        XCTAssertTrue(deleted)
        XCTAssertFalse(PlaybackProgress.shared.hasProgress(
            MusicFile(relativePath: onePath, name: "one.mp3")
        ))
        XCTAssertFalse(PlaybackProgress.shared.hasProgress(
            MusicFile(relativePath: twoPath, name: "two.mp3")
        ))
        XCTAssertTrue(
            PlaybackProgress.shared.hasProgress(
                MusicFile(relativePath: otherPath, name: other.lastPathComponent)
            ),
            "删除一个文件夹不能清掉其他文件的播放记录"
        )
    }

    func testDeletingFileRemovesTheCorrectSnapshotRow() async throws {
        let root = LibraryPaths.root
        let first = root.appendingPathComponent(
            "delete-row-a-\(UUID().uuidString).mp3"
        )
        let second = root.appendingPathComponent(
            "delete-row-b-\(UUID().uuidString).mp3"
        )
        try Data([0x01]).write(to: first)
        try Data([0x02]).write(to: second)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
            PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: first))
            PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: second))
        }

        let model = DirectoryModel(directory: root, isRoot: true)
        await model.load()
        XCTAssertTrue(model.music.contains { $0.url == first })
        XCTAssertTrue(model.music.contains { $0.url == second })

        let deleted = await model.delete([first])

        XCTAssertTrue(deleted)
        XCTAssertFalse(
            model.music.contains { $0.url.standardizedFileURL == first.standardizedFileURL }
        )
        XCTAssertTrue(
            model.music.contains { $0.url.standardizedFileURL == second.standardizedFileURL },
            "删除一行后必须保留下面一行，不能发生行错位"
        )
    }

    private func makePlayableFixture(named name: String) throws -> (url: URL, file: MusicFile) {
        let url = LibraryPaths.root.appendingPathComponent(
            "progress-\(name)-\(UUID().uuidString).mp3"
        )
        try Data([0x00]).write(to: url)
        return (
            url,
            MusicFile(relativePath: LibraryPaths.relativePath(of: url), name: url.lastPathComponent)
        )
    }

    private func cleanup(
        _ first: (url: URL, file: MusicFile),
        _ second: (url: URL, file: MusicFile)
    ) {
        try? FileManager.default.removeItem(at: first.url)
        try? FileManager.default.removeItem(at: second.url)
        PlaybackProgress.shared.clear(first.file.relativePath)
        PlaybackProgress.shared.clear(second.file.relativePath)
        UserDefaults.standard.removeObject(forKey: "lastPlayedPath")
    }
}
