import Foundation

class UploadingManager {

    // Configure once at app startup to provide the destination endpoint and optional token provider
    private static var endpointURL: URL?
    private static var tokenProvider: (() -> String?)?

    static func configure(endpointURL: URL, tokenProvider: (() -> String?)? = nil) {
        self.endpointURL = endpointURL
        self.tokenProvider = tokenProvider
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
        guard let endpoint = endpointURL else {
            print("UploadingManager not configured with endpointURL")
            return nil
        }

        return await withCheckedContinuation { continuation in
            var task: UploadTask? = UploadTask(
                data: data,
                ofType: ext,
                parameters: [
                    ["url": endpoint.absoluteString]
                ]
            )

            if let provider = tokenProvider {
                task?.setTokenProvider(provider)
            }

            task?.setCompletionHandler { _, remote in
                continuation.resume(returning: remote)
                task = nil
            }

            task?.setErrorHandler { error in
                print("Upload error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
                task = nil
            }
        }
    }
}
