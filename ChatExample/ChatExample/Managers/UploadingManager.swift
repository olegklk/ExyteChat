import Foundation

class UploadingManager {

    // Configure once at app startup to provide the destination endpoint and optional token provider
    private actor UploadingConfig {
        var endpointURL: URL?
        var tokenProvider: (@Sendable () -> String?)?
        func set(endpointURL: URL, tokenProvider: (@Sendable () -> String?)?) {
            self.endpointURL = endpointURL
            self.tokenProvider = tokenProvider
        }
        func get() -> (URL?, (@Sendable () -> String?)?) {
            (endpointURL, tokenProvider)
        }
    }
    private static let config = UploadingConfig()

    static func configure(endpointURL: URL, tokenProvider: (@Sendable () -> String?)? = nil) {
        Task { await config.set(endpointURL: endpointURL, tokenProvider: tokenProvider) }
    }

    static func uploadImageMedia(_ media: Media?) async -> URL? {
        guard let data = await media?.getData() else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        return await performUpload(data: data, ext: "jpg", fileName: fileName)
    }

    // Returns (thumbnailURL, fullURL)
    static func uploadVideoMedia(_ media: Media?) async -> (URL?, URL?) {
        guard let thumbData = await media?.getThumbnailData(),
              let data = await media?.getData() else { return (nil, nil) }
        let base = UUID().uuidString
        let thumbURL = await performUpload(data: thumbData, ext: "jpg", fileName: "\(base)-thumb.jpg")
        let fullURL = await performUpload(data: data, ext: "mov", fileName: "\(base).mov")
        return (thumbURL, fullURL)
    }

    static func uploadRecording(_ recording: Recording?) async -> URL? {
        guard let url = recording?.url, let data = try? Data(contentsOf: url) else { return nil }
        let fileName = url.deletingPathExtension().lastPathComponent + ".aac"
        return await performUpload(data: data, ext: "aac", fileName: fileName)
    }
    static func uploadImageData(_ data: Data?) async -> URL? {
        guard let data = data else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        return await performUpload(data: data, ext: "jpg", fileName: fileName)
    }

    // MARK: - Private

    private static func performUpload(data: Data, ext: String, fileName: String) async -> URL? {
        let (endpointOpt, tokenProvider) = await config.get()
        guard let endpoint = endpointOpt else {
            print("UploadingManager not configured with endpointURL")
            return nil
        }

        do {
            let url = try await UploadTask.upload(
                data: data,
                ofType: ext,
                to: endpoint,
                fileName: fileName,
                tokenProvider: tokenProvider
            )
            return url
        } catch {
            print("Upload error: \(error.localizedDescription)")
            return nil
        }
    }
}
