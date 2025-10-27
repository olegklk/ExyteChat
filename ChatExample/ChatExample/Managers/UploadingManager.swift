import Foundation

class UploadingManager {

    // Configure once at app startup to provide the destination endpoint and optional token provider
    private actor UploadingConfig {
        var endpointURL: URL?
        var tokenProvider: (() -> String?)?
        func set(endpointURL: URL, tokenProvider: (() -> String?)?) {
            self.endpointURL = endpointURL
            self.tokenProvider = tokenProvider
        }
        func get() -> (URL?, (() -> String?)?) {
            (endpointURL, tokenProvider)
        }
    }
    private static let config = UploadingConfig()

    static func configure(endpointURL: URL, tokenProvider: (() -> String?)? = nil) {
         config.set(endpointURL: endpointURL, tokenProvider: tokenProvider) //Call to actor-isolated instance method 'set(endpointURL:tokenProvider:)' in a synchronous nonisolated context AI!
    }

    static func uploadImageMedia(_ media: Media?) async -> URL? {
        guard let data = await media?.getData() else { return nil }
        return await performUpload(data: data, ext: "jpg")
    }

    // Returns (thumbnailURL, fullURL)
    static func uploadVideoMedia(_ media: Media?) async -> (URL?, URL?) {
        guard let thumbData = await media?.getThumbnailData(),
              let data = await media?.getData() else { return (nil, nil) }
        let thumbURL = await performUpload(data: thumbData, ext: "jpg")
        let fullURL = await performUpload(data: data, ext: "mov")
        return (thumbURL, fullURL)
    }

    static func uploadRecording(_ recording: Recording?) async -> URL? {
        guard let url = recording?.url, let data = try? Data(contentsOf: url) else { return nil }
        return await performUpload(data: data, ext: "aac")
    }

    static func uploadImageData(_ data: Data?) async -> URL? {
        guard let data = data else { return nil }
        return await performUpload(data: data, ext: "jpg")
    }

    // MARK: - Private

    private static func performUpload(data: Data, ext: String) async -> URL? {
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
                tokenProvider: tokenProvider
            )
            return url
        } catch {
            print("Upload error: \(error.localizedDescription)")
            return nil
        }
    }
}
