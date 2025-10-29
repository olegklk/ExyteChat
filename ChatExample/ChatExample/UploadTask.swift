import Foundation
import ImageIO

enum UploadTaskError: Error {
    case missingRemoteURL
}

final class UploadTask {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 240
        return URLSession(configuration: config)
    }()

    // MARK: - Public API (async/await)

    /// Upload raw data to endpoint and return remote URL parsed from server JSON ("uri" or "url").
    static func upload(
        data: Data,
        ofType ext: String,
        to endpoint: URL,
        fileName: String? = nil,
        tokenProvider: (@Sendable () -> String?)? = nil
    ) async throws -> URL {
        var finalURL = endpoint
        if let fileName = fileName, !fileName.isEmpty {
            finalURL = finalURL.appendingPathComponent(fileName)
        }
        if ext.lowercased() == "jpg",
           let (w, h) = imagePixelSize(from: data) {
            if var comps = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) {
                var items = comps.queryItems ?? []
                items.append(URLQueryItem(name: "width", value: String(w)))
                items.append(URLQueryItem(name: "height", value: String(h)))
                comps.queryItems = items
                finalURL = comps.url ?? finalURL
            }
        }
        var request = URLRequest(url: finalURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 240.0)
        request.httpMethod = "POST"
        if let token = tokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let mime = mimeType(forExtension: ext)
        request.setValue(mime, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (responseData, response) = try await session.upload(for: request, from: data)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let message: String
            if let obj = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let m = (obj["message"] as? String) ?? (obj["error"] as? String) {
                message = m
            } else {
                message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            }
            throw NSError(domain: "UploadTask", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        if let remote = try parseRemoteURL(from: responseData) {
            return remote
        } else {
            throw UploadTaskError.missingRemoteURL
        }
    }

    /// Upload a local file to endpoint and return remote URL parsed from server JSON ("uri" or "url").
    static func upload(
        fileURL: URL,
        to endpoint: URL,
        fileName: String? = nil,
        tokenProvider: (@Sendable () -> String?)? = nil
    ) async throws -> URL {
        let data = try Data(contentsOf: fileURL)
        let name = fileName ?? fileURL.lastPathComponent
        return try await upload(data: data, ofType: fileURL.pathExtension, to: endpoint, fileName: name, tokenProvider: tokenProvider)
    }

    // MARK: - Private

    private static func imagePixelSize(from data: Data) -> (Int, Int)? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        if let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            return (w, h)
        }
        if let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
           let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
            return (Int(w), Int(h))
        }
        return nil
    }

    private static func parseRemoteURL(from data: Data) throws -> URL? {
        guard !data.isEmpty else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let uri = (json["uri"] as? String) ?? (json["url"] as? String) {
                return URL(string: uri)
            }
        }
        return nil
    }

    private static func mimeType(forExtension ext: String) -> String {
        let lower = ext.lowercased()
        switch lower {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4a": return "audio/m4a"
        case "aac": return "audio/aac"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}
