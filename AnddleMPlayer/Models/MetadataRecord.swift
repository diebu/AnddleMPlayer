import Foundation

/// 一条缓存下来的标签记录。用「相对路径 + 文件大小 + 修改时间」判定是否还有效，
/// 所以重命名、移动、替换文件之后会自动重读，不会出现封面错位。
struct MetadataRecord: Codable {
    var size: Int64
    var modified: Double
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var artwork: String?
}
