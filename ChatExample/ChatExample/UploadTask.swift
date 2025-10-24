import Foundation

/// A lightweight, Swift-native upload helper with closure-based callbacks and no ObjC/UIKit dependencies.
final class UploadTask {

    // MARK: Public API

    /// Progress handler: 0.0 ... 1.0
    func setProgressHandler(_ handler: @escaping (Double) -> Void) { self.onProgress = handler }

    /// Completion handler: (localURL, remoteURL)
    func setCompletionHandler(_ handler: @escaping (URL?, URL?) -> Void) { self.onComplete = handler }

    /// Error handler
    func setErrorHandler(_ handler: @escaping (Error) -> Void) { self.onError = handler }

    /// Cancels the ongoing upload
    func cancel() {
        isCanceled = true
        progressObservation?.invalidate()
        uploadTask?.cancel()
        uploadTask = nil
    }

    // MARK: Initializers

    /// Designated initializer
    /// - Parameters:
    ///   - url: Destination endpoint (full URL). If nil, you must pass one in `parameters` using "url" key in [String: String] or provide later – otherwise init will fail.
    ///   - data: Data to upload.
    ///   - parameters: Optional query parameters. Accepts either [URLQueryItem] or [String: String]. Any other values are ignored.
    ///   - mime: Content-Type for the upload. Defaults to "application/octet-stream".
    ///   - onProgress: Progress callback 0...1
    ///   - onComplete: Completion callback with (local, remote) URLs parsed from server JSON ("uri" or "url" fields).
    ///   - onError: Error callback
    init(
        url: URL?,
        data: Data,
        parameters: [Any],
        mime: String?,
        onProgress: ((Double) -> Void)? = nil,
        onComplete: ((URL?, URL?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.data = data
        self.parameters = parameters
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError

        self.url = url
        self.mime = mime ?? "application/octet-stream"

        // Create a temporary local file URL if none provided (useful for clients expecting a file URL)
        if self.url == nil {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(UUID().uuidString)
            try? data.write(to: tempURL, options: .atomic)
            self.url = tempURL
        }

        start()
    }

    /// Convenience initializer to set MIME type by file extension (very small built-in mapping)
    convenience init(data: Data, ofType ext: String, parameters: [Any]) {
        let mime = UploadTask.mimeType(forExtension: ext)
        self.init(url: nil, data: data, parameters: parameters, mime: mime)
    }

    /// Convenience initializer to read data from a file URL
    convenience init(fileURL: URL, parameters: [Any]) {
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        self.init(url: fileURL, data: data, parameters: parameters, mime: UploadTask.mimeType(forExtension: fileURL.pathExtension))
    }

    // MARK: Private

    private var data: Data
    private var parameters: [Any] = []
    private var uploadTask: URLSessionUploadTask?
    private var isCanceled = false
    private var onProgress: ((Double) -> Void)?
    private var onComplete: ((URL?, URL?) -> Void)?
    private var onError: ((Error) -> Void)?
    private var progressObservation: NSKeyValueObservation?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // Reasonable defaults
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 240
        return URLSession(configuration: config)
    }()

    private(set) var url: URL!
    private(set) var remoteUrl: URL?
    private(set) var mime: String!

    private func start() {
        guard var endpoint = buildEndpointURL() else {
            onError?(URLError(.badURL))
            return
        }

        // Append parameters to URL as query items if provided
        if let items = parametersAsQueryItems(parameters), !items.isEmpty {
            var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) ?? URLComponents()
            var current = comps.queryItems ?? []
            current.append(contentsOf: items)
            comps.queryItems = current
            endpoint = comps.url ?? endpoint
        }

        var request = URLRequest(url: endpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 240.0)
        request.httpMethod = "POST"
        request.setValue(mime, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Create task
        let task = session.uploadTask(with: request, from: data) { [weak self] data, response, error in
            guard let self else { return }
            if self.isCanceled { return }

            if let error {
                DispatchQueue.main.async { self.onError?(error) }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { self.onError?(URLError(.badServerResponse)) }
                return
            }

            guard (200...299).contains(http.statusCode) else {
                let message: String
                if let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let m = (obj["message"] as? String) ?? (obj["error"] as? String) {
                    message = m
                } else {
                    message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                }
                let error = NSError(domain: "UploadTask", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                DispatchQueue.main.async { self.onError?(error) }
                return
            }

            // Parse JSON response looking for "uri" or "url"
            var localURL: URL? = self.url
            var remoteURL: URL? = nil
            if let data, !data.isEmpty,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let uri = (json["uri"] as? String) ?? (json["url"] as? String) {
                    remoteURL = URL(string: uri)
                }
            }

            self.remoteUrl = remoteURL
            DispatchQueue.main.async {
                self.onComplete?(localURL, remoteURL)
            }
        }

        // Observe progress
        progressObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] prog, _ in
            guard let self else { return }
            if self.isCanceled { return }
            DispatchQueue.main.async {
                self.onProgress?(prog.fractionCompleted)
            }
        }

        uploadTask = task
        task.resume()
    }

    private func buildEndpointURL() -> URL? {
        // If `parameters` contains a "url" string, use it; otherwise rely on a fixed endpoint per use-site.
        // The previous implementation used external managers; we now expect a full URL to be passed in.
        // If `url` property holds a file URL (most common), it is NOT the endpoint, just the local file.
        // So we check parameters first, then fall back to `url` if it's actually a network URL.
        if let endpointFromParams = endpointURLFromParameters(parameters) {
            return endpointFromParams
        }
        if let u = url, u.scheme?.lowercased().hasPrefix("http") == true {
            return u
        }
        return nil
    }

    private func parametersAsQueryItems(_ params: [Any]) -> [URLQueryItem]? {
        if let items = params as? [URLQueryItem] {
            return items
        }
        if let dict = params.first as? [String: String] {
            return dict.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return nil
    }

    private func endpointURLFromParameters(_ params: [Any]) -> URL? {
        // Accept either [String: String] with "url": "https://..." or a direct URL passed as the first element
        if let dict = params.first as? [String: String], let urlString = dict["url"], let url = URL(string: urlString) {
            return url
        }
        if let u = params.first as? URL {
            return u
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
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}
