import XCTest
@testable import AnddleMPlayer

final class FormattingTests: XCTestCase {
    func testTimeFormattingHandlesBoundariesAndInvalidValues() {
        XCTAssertEqual(fmtTime(-1), "0:00")
        XCTAssertEqual(fmtTime(0), "0:00")
        XCTAssertEqual(fmtTime(59.6), "1:00")
        XCTAssertEqual(fmtTime(65), "1:05")
        XCTAssertEqual(fmtTime(3_661), "1:01:01")
        XCTAssertEqual(fmtTime(.nan), "0:00")
    }

    func testFileNameWrappingProtectsBracketsAndBreaksAfterSemicolon() {
        let wrapped = fileNameForNaturalWrapping("标题（现场版）；下一段")

        XCTAssertTrue(wrapped.contains("\u{2060}现"))
        XCTAssertTrue(wrapped.contains("\u{2060}）"))
        XCTAssertTrue(wrapped.contains("；\u{200B}下"))
        XCTAssertFalse(wrapped.contains("；\u{200B}\u{2060}"))
    }

    func testFolderDisplayNameRemovesCommonSequencePrefixes() {
        XCTAssertEqual(FilenameParser.folderDisplayName("01 哈利波特"), "哈利波特")
        XCTAssertEqual(FilenameParser.folderDisplayName("02. 密室"), "密室")
        XCTAssertEqual(FilenameParser.folderDisplayName("第03章 阿兹卡班"), "阿兹卡班")
        XCTAssertEqual(FilenameParser.folderDisplayName("(04) 火焰杯"), "火焰杯")
        XCTAssertEqual(FilenameParser.folderDisplayName("2024年度合集"), "2024年度合集")
    }

    func testBalancedFolderNameLines() {
        XCTAssertEqual(balancedFileNameLines("哈利波特"), "哈利\n波特")
        XCTAssertEqual(balancedFileNameLines("哈利波特与"), "哈利波\n特与")
        XCTAssertEqual(balancedFileNameLines("哈利波特与魔法石"), "哈利波\n特与魔\n法石")
        XCTAssertEqual(balancedFileNameLines("音乐"), "音乐")
    }
}
