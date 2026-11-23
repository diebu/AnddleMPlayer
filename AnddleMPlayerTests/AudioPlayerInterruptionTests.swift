import AVFoundation
import XCTest
@testable import AnddleMPlayer

@MainActor
final class AudioPlayerInterruptionTests: XCTestCase {
    func testInterruptionPausesAndFirstToggleResumesPlayback() throws {
        let fixture = try makePlayableFixture()
        defer { fixture.cleanup() }

        let player = AudioPlayer()
        player.play(fixture.file, in: [fixture.file])
        XCTAssertTrue(player.isPlaying)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey:
                    AVAudioSession.InterruptionType.began.rawValue
            ]
        )

        XCTAssertFalse(
            player.isPlaying,
            "系统音频打断后必须同步为暂停，否则第一次点击只会再次暂停"
        )

        player.toggle()
        XCTAssertTrue(player.isPlaying, "打断后第一次点击应当直接恢复播放")
        player.pause()
    }

    func testInterruptionEndDoesNotAutoResume() throws {
        let fixture = try makePlayableFixture()
        defer { fixture.cleanup() }

        let player = AudioPlayer()
        player.play(fixture.file, in: [fixture.file])

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey:
                    AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey:
                    AVAudioSession.InterruptionType.ended.rawValue
            ]
        )

        XCTAssertFalse(player.isPlaying, "打断结束不能未经用户操作自动播放")
    }

    private func makePlayableFixture() throws -> Fixture {
        let url = LibraryPaths.root.appendingPathComponent(
            "interruption-test-\(UUID().uuidString).mp3"
        )
        try Data([0x00]).write(to: url)
        let relativePath = LibraryPaths.relativePath(of: url)
        return Fixture(
            url: url,
            file: MusicFile(relativePath: relativePath, name: url.lastPathComponent)
        )
    }

    private struct Fixture {
        var url: URL
        var file: MusicFile

        func cleanup() {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.standard.removeObject(forKey: "lastPlayedPath")
        }
    }
}
