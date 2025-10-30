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
    // Result-based API
    enum UploadingManagerError: Error {
        case notConfiguredEndpoint
        case missingMedia
        case missingData
    }

    static func uploadImageMediaResult(_ media: Media?) async -> Result<URL, Error> {
        guard let media = media else { return .failure(UploadingManagerError.missingMedia) }
        guard let data = await media.getData() else { return .failure(UploadingManagerError.missingData) }
        let fileName = media.id.uuidString
        return await performUploadResult(data: data, ext: "jpg", fileName: fileName)
    }

    // Returns (thumbnailURL, fullURL)
    static func uploadVideoMediaResult(_ media: Media?) async -> Result<(URL, URL), Error> {
        guard let media = media else { return .failure(UploadingManagerError.missingMedia) }
        guard let thumbData = await media.getThumbnailData(),
              let data = await media.getData() else { return .failure(UploadingManagerError.missingData) }

        let base = media.id.uuidString
        switch await performUploadResult(data: thumbData, ext: "jpg", fileName: "\(base)-thumb.jpg") {
        case .success(let thumbURL):
            switch await performUploadResult(data: data, ext: "mov", fileName: "\(base).mov") {
            case .success(let fullURL):
                return .success((thumbURL, fullURL))
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    static func uploadRecordingResult(_ recording: Recording?) async -> Result<URL, Error> {
        guard let url = recording?.url, let data = try? Data(contentsOf: url) else {
            return .failure(UploadingManagerError.missingData)
        }
        let fileName = url.deletingPathExtension().lastPathComponent + ".aac"
        return await performUploadResult(data: data, ext: "aac", fileName: fileName)
    }

    static func uploadImageDataResult(_ data: Data?) async -> Result<URL, Error> {
        guard let data = data else { return .failure(UploadingManagerError.missingData) }
        let fileName = UUID().uuidString + ".jpg"
        return await performUploadResult(data: data, ext: "jpg", fileName: fileName)
    }
    static func uploadImageMedia(_ media: Media?) async -> URL? {
        guard let media = media else { return nil }
        guard let data = await media.getData() else { return nil }
        
        let fileName = media.id.uuidString //+ ".jpg"
        return await performUpload(data: data, ext: "jpg", fileName: fileName)
    }

    // Returns (thumbnailURL, fullURL)
    static func uploadVideoMedia(_ media: Media?) async -> (URL?, URL?) {
        guard let media = media else { return (nil,nil)}
        guard let thumbData = await media.getThumbnailData(),
              let data = await media.getData() else { return (nil, nil) }
        
        let base = media.id.uuidString
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

    private static func performUploadResult(data: Data, ext: String, fileName: String) async -> Result<URL, Error> {
        let (endpointOpt, tokenProvider) = await config.get()
        guard let endpoint = endpointOpt else {
            return .failure(UploadingManagerError.notConfiguredEndpoint)
        }

        do {
            let url = try await UploadTask.upload(
                data: data,
                ofType: ext,
                to: endpoint,
                fileName: fileName,
                tokenProvider: tokenProvider
            )
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

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
