import Foundation

/// 章节图片解码器 —— 移植自 goda.js（keiyoushi/extensions-source PR #16898）。
///
/// /api/v2/chapter/getinfo 返回的 images 字段是被混淆过的字符串，需要还原为
/// 原始的图片 JSON 数组。
///
/// 流程：去掉 "J7r" 前缀 / "nQ" 后缀 → 依据 "kD"、"W4s" 标记切成 3 段 →
/// 重排为 part3+part1+part2 → 每隔一个 7 字符块反转 → 自定义字母表映射回标准
/// base64url → base64 解码 → UTF-8 JSON。
enum ChapterImageDecoder {

    private static let std = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)
    private static let custom = Array("_-9876543210abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)

    private static let prefix = Array("J7r".utf8)
    private static let marker1 = Array("kD".utf8)
    private static let marker2 = Array("W4s".utf8)
    private static let suffix = Array("nQ".utf8)
    private static let group = 7

    /// custom 字符 → std 字符 的查表；-1 表示非法字符
    private static let table: [Int16] = {
        var t = [Int16](repeating: -1, count: 128)
        for i in 0..<custom.count {
            t[Int(custom[i])] = Int16(std[i])
        }
        return t
    }()

    struct RawImage: Decodable {
        let order: Int?
        let url: String
    }

    enum DecodeError: Error, LocalizedError {
        case badFormat
        case invalidCharacter
        case base64Failed
        case jsonFailed

        var errorDescription: String? {
            switch self {
            case .badFormat: return "未知的章节数据格式"
            case .invalidCharacter: return "无效的章节数据字符"
            case .base64Failed: return "章节数据 Base64 解码失败"
            case .jsonFailed: return "章节数据 JSON 解析失败"
            }
        }
    }

    /// 输入混淆字符串，输出图片相对路径数组（保持原顺序）
    static func decode(_ input: String) throws -> [RawImage] {
        let bytes = Array(input.utf8)

        guard bytes.count > prefix.count + suffix.count,
              hasPrefix(bytes, prefix),
              hasSuffix(bytes, suffix) else {
            throw DecodeError.badFormat
        }

        let body = Array(bytes[prefix.count..<(bytes.count - suffix.count)])
        let payloadLen = body.count - marker1.count - marker2.count
        guard payloadLen > 0 else { throw DecodeError.badFormat }

        let aLen = payloadLen / 3
        let bLen = (payloadLen - aLen) / 2
        let cLen = payloadLen - aLen - bLen

        var cursor = 0
        let part1 = Array(body[cursor..<(cursor + bLen)]); cursor += bLen
        let mk1 = Array(body[cursor..<(cursor + marker1.count)]); cursor += marker1.count
        let part2 = Array(body[cursor..<(cursor + cLen)]); cursor += cLen
        let mk2 = Array(body[cursor..<(cursor + marker2.count)]); cursor += marker2.count
        let part3 = Array(body[cursor...])

        guard mk1 == marker1, mk2 == marker2, part3.count == aLen else {
            throw DecodeError.badFormat
        }

        // 重排：part3 + part1 + part2
        var reordered = [UInt8]()
        reordered.reserveCapacity(body.count)
        reordered.append(contentsOf: part3)
        reordered.append(contentsOf: part1)
        reordered.append(contentsOf: part2)

        // 去 zigzag：每隔一个 group 块反转
        var unzig = [UInt8]()
        unzig.reserveCapacity(reordered.count)
        var i = 0
        var block = 0
        while i < reordered.count {
            let end = min(i + group, reordered.count)
            let chunk = reordered[i..<end]
            if block % 2 == 1 {
                unzig.append(contentsOf: chunk.reversed())
            } else {
                unzig.append(contentsOf: chunk)
            }
            i += group
            block += 1
        }

        // 自定义字母表 → 标准 base64url
        var standard = [UInt8]()
        standard.reserveCapacity(unzig.count)
        for c in unzig {
            let mapped = c < 128 ? table[Int(c)] : -1
            guard mapped >= 0 else { throw DecodeError.invalidCharacter }
            standard.append(UInt8(mapped))
        }

        // base64url → 标准 base64（-_ → +/），补齐 padding
        for idx in standard.indices {
            if standard[idx] == UInt8(ascii: "-") { standard[idx] = UInt8(ascii: "+") }
            else if standard[idx] == UInt8(ascii: "_") { standard[idx] = UInt8(ascii: "/") }
        }
        while standard.count % 4 != 0 {
            standard.append(UInt8(ascii: "="))
        }

        guard let b64String = String(bytes: standard, encoding: .ascii),
              let data = Data(base64Encoded: b64String) else {
            throw DecodeError.base64Failed
        }

        guard let images = try? JSONDecoder().decode([RawImage].self, from: data) else {
            throw DecodeError.jsonFailed
        }
        return images
    }

    private static func hasPrefix(_ bytes: [UInt8], _ p: [UInt8]) -> Bool {
        guard bytes.count >= p.count else { return false }
        for i in 0..<p.count where bytes[i] != p[i] { return false }
        return true
    }

    private static func hasSuffix(_ bytes: [UInt8], _ s: [UInt8]) -> Bool {
        guard bytes.count >= s.count else { return false }
        let off = bytes.count - s.count
        for i in 0..<s.count where bytes[off + i] != s[i] { return false }
        return true
    }
}