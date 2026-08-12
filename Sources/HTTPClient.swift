import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case noData
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的地址"
        case .badStatus(let code): return "请求失败（HTTP \(code)）"
        case .noData: return "没有获取到数据"
        case .decoding(let msg): return "数据解析失败：\(msg)"
        }
    }
}

/// 轻量 URLSession 封装：统一 Header、超时、重试
final class HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    /// GET 返回原始 Data
    func getData(_ urlString: String,
                 headers: [String: String],
                 retries: Int = 2) async throws -> Data {
        guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }

        var lastError: Error = NetworkError.noData
        for attempt in 0...max(0, retries) {
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                guard (200...299).contains(http.statusCode) else {
                    throw NetworkError.badStatus(http.statusCode)
                }
                return data
            } catch {
                lastError = error
                if attempt < retries {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 400_000_000))
                    continue
                }
            }
        }
        throw lastError
    }

    /// GET 返回 HTML/文本
    func getString(_ urlString: String,
                   headers: [String: String],
                   retries: Int = 2) async throws -> String {
        let data = try await getData(urlString, headers: headers, retries: retries)
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw NetworkError.decoding("无法解码文本")
    }

    /// GET 返回 JSON 解码对象
    func getJSON<T: Decodable>(_ urlString: String,
                               headers: [String: String],
                               as type: T.Type,
                               retries: Int = 2) async throws -> T {
        let data = try await getData(urlString, headers: headers, retries: retries)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }
}