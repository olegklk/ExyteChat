import Foundation

@objcMembers
class UploadTask: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, ClientToServerDelegate {

    static var sWaitingForNewAuthTokens: Bool = false

    private var data: Data
    private var totalBytes: Int64 = 0
    private var parameters: [Any] = []
    private var response: URLResponse?
    private var responseData = Data()
    private var networkAccess: AnyObject?
    private var uploadTask: URLSessionUploadTask?
    private var isCanceled = false
    private var waitingForNewAuthTokens = false
    // Removed RAC; use closures for progress and completion
    private var onProgress: ((Double) -> Void)?
    private var onComplete: ((URL?, URL?) -> Void)?
    private var onError: ((Error) -> Void)?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private(set) var url: URL!
    private(set) var remoteUrl: URL?
    private(set) var mime: String!
    private(set) lazy var progress: Progress = {
        let p = Progress(totalUnitCount: 0)
        p.isPausable = false
        p.isCancellable = false
        return p
    }()

    // Removed RAC signal API. Use setProgressHandler(_:), setCompletionHandler(_:), and setErrorHandler(_:) instead.
    func setProgressHandler(_ handler: @escaping (Double) -> Void) { self.onProgress = handler }
    func setCompletionHandler(_ handler: @escaping (URL?, URL?) -> Void) { self.onComplete = handler }
    func setErrorHandler(_ handler: @escaping (Error) -> Void) { self.onError = handler }

    // MARK: - Initializers

    init(url: URL?, data: Data, parameters: [Any], mime: String?, onProgress: ((Double) -> Void)? = nil, onComplete: ((URL?, URL?) -> Void)? = nil, onError: ((Error) -> Void)? = nil) {
        self.data = data
        self.parameters = parameters
        super.init()

        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError

        self.url = url

        if let providedMime = mime {
            self.mime = providedMime
        } else if let u = url {
            // try to resolve mime from URL via ObjC category
            if let mimeFromURL = (u as NSURL).mimeType?() as String? {
                self.mime = mimeFromURL
            } else {
                self.mime = "application/octet-stream"
            }
        } else {
            self.mime = "application/octet-stream"
        }

        if self.url == nil {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
            let uuid = UUID().uuidString
            let tempURL = URL(fileURLWithPath: path).appendingPathComponent("temp/\(uuid)")
            try? FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try? data.write(to: tempURL, options: .atomic)
            self.url = tempURL
        }

        responseData = Data()

        DDLogInfo("Starting upload <\(Unmanaged.passUnretained(self).toOpaque())> of \(self.url.absoluteString). Parameters: \(parameters)")

        let request = self.request(with: self.data)
        self.uploadTask = session.uploadTask(with: request, from: self.data)
        self.uploadTask?.resume()

        self.networkAccess = ApplicationState.instance().beginSignalNetworkAccess()

        ClientToServer.instance().addDelegate(self)
    }

    convenience init(data: Data, ofType ext: String, parameters: [Any]) {
        let mime = (NSURL.fileType(fromExtension: ext) as String?) ?? "application/octet-stream"
        self.init(url: nil, data: data, parameters: parameters, mime: mime)
    }

    convenience init(fileURL: URL, parameters: [Any]) {
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        self.init(url: fileURL, data: data, parameters: parameters, mime: nil)
    }

    // MARK: - Public

    func cancel() {
        DDLogDebug("cancel \(String(describing: uploadTask?.currentRequest))")
        isCanceled = true
        uploadTask?.cancel()
        uploadTask = nil
    }

    // MARK: - Private

    private func addBasicAuth(to request: inout URLRequest) {
        var username = LocalUserProfile.instance().userID
        var password = "password"

        if let uploadPass = LocalUserProfile.instance().uploadAuthPass, let sessionID = LocalUserProfile.instance().sessionID {
            username = sessionID
            password = uploadPass
        }

        if let method = request.httpMethod, let url = request.url {
            let message = CFHTTPMessageCreateRequest(nil, method as CFString, url as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
            CFHTTPMessageAddAuthentication(message, nil, username as CFString, password as CFString, kCFHTTPAuthenticationSchemeBasic, false)
            if let authString = CFHTTPMessageCopyHeaderFieldValue(message, "Authorization" as CFString)?.takeRetainedValue() as String? {
                request.setValue(authString, forHTTPHeaderField: "Authorization")
            }
        }
    }

    private func request(with data: Data) -> URLRequest {
        DDLogInfo("About to upload data (length=\(UInt64(data.count)))")

        let remoteName = ((self.url.lastPathComponent as NSString).deletingPathExtension).lowercased()

        guard let base = URL(string: ServerAddressManager.instance().uploadURI()) else {
            fatalError("Invalid upload URI")
        }
        var uploadURL = base.appendingPathComponent(remoteName)

        // add query parameters via ObjC NSURL category
        if !parameters.isEmpty {
            if let u = NSURL.addQueryParameters?(parameters as NSArray, to: uploadURL) as URL? {
                uploadURL = u
            }
        }

        var request = URLRequest(url: uploadURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 240.0)

        if let jwt = LocalUserProfile.instance().jwt(), !jwt.isEmpty {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        } else {
            addBasicAuth(to: &request)
        }

        request.httpMethod = "POST"
        if let mime = self.mime {
            request.setValue(mime, forHTTPHeaderField: "Content-Type")
        }
        request.setValue(String(UInt64(data.count)), forHTTPHeaderField: "Content-Length")

        return request
    }

    private func restartIfNeeded() {
        if !waitingForNewAuthTokens { return }
        waitingForNewAuthTokens = false
        if isCanceled {
            DDLogDebug("skip restarting canceled task")
            return
        }

        uploadTask?.cancel()
        uploadTask = nil

        responseData = Data()
        let request = self.request(with: self.data)
        self.uploadTask = session.uploadTask(with: request, from: self.data)
        self.uploadTask?.resume()

        self.networkAccess = ApplicationState.instance().beginSignalNetworkAccess()
    }

    private func didFinish(with error: Error?) {
        if error == nil {
            self.networkAccess = nil
            self.response = self.uploadTask?.response
            let httpResponse = self.response as? HTTPURLResponse
            let contentType = httpResponse?.allHeaderFields["Content-Type"] as? String

            self.progress.completedUnitCount = self.progress.totalUnitCount

            if httpResponse?.statusCode == 200 && contentType == "application/json" {
                if let json = try? JSONSerialization.jsonObject(with: self.responseData, options: []),
                   let dict = json as? [String: Any] {
                    var uri = dict["uri"] as? String
                    let urlStr = dict["url"] as? String

                    if uri == nil, let urlStr = urlStr {
                        uri = urlStr
                    }

                    if let uri = uri {
                        if let urlStr = urlStr {
                            if let fileURL = (NSURL.serverResourceURLfromRelativeURLString?(urlStr.lowercased()) as URL?) {
                                DDLogInfo("Upload <\(Unmanaged.passUnretained(self).toOpaque())> finished, server URL: \(fileURL.absoluteString)")

                                if let mime = self.mime, mime.hasPrefix("image/"),
                                   let imageToCache = UIImage(data: self.data) {
                                    ImageDownloader.store(withImage: imageToCache, forKey: urlStr)
                                }

                                if let scheme = self.url.scheme, let dmzScheme = DMZCacheScheme, scheme == dmzScheme {
                                    if let converted = (self.url as NSURL).fileURLFromDMZCacheURL?() as URL? {
                                        self.url = converted
                                    }
                                }

                                if let mime = self.mime, mime.hasPrefix("image/"),
                                   let thumbLocalURL = (self.url as NSURL).thumbnailURL?() as URL?,
                                   let thumbData = try? Data(contentsOf: thumbLocalURL),
                                   let thumbnailToCache = UIImage(data: thumbData) {
                                    if let remoteThumbnailURL = (fileURL as NSURL).thumbnailURL?() as URL? {
                                        ImageDownloader.store(withImage: thumbnailToCache, forKey: remoteThumbnailURL.absoluteString)
                                    }
                                }

                                // delete uploaded file from temp folder
                                try? FileManager.default.removeItem(at: self.url)
                                if let thumbLocalURL = (self.url as NSURL).thumbnailURL?() as URL? {
                                    try? FileManager.default.removeItem(at: thumbLocalURL)
                                }
                            }
                        }

                        self.url = URL(string: uri)
                        if let urlStr = urlStr {
                            self.remoteUrl = URL(string: urlStr)
                        }

                        self.onComplete?(self.url, self.remoteUrl)
                    } else {
                        DDLogError("Upload <\(Unmanaged.passUnretained(self).toOpaque())> finished, but no server URL was provided")
                        self.onError?(NSError(domain: "DMZUploadTaskError", code: 666, userInfo: nil))
                    }
                } else {
                    DDLogError("Upload <\(Unmanaged.passUnretained(self).toOpaque())> finished, but response JSON parsing failed")
                    self.onError?(NSError(domain: "DMZUploadTaskError", code: 666, userInfo: nil))
                }
            } else {
                let req = self.uploadTask?.currentRequest
                DDLogError("Upload <\(Unmanaged.passUnretained(self).toOpaque())> finished with status code: \(httpResponse?.statusCode ?? -1) (Failed!), request URL: \(String(describing: req?.url)), has auth: \((req?.allHTTPHeaderFields?["Authorization"] != nil) ? "YES" : "NO"), task \(String(describing: self.uploadTask)), state \(self.uploadTask?.state.rawValue ?? -1)")

                if httpResponse?.statusCode == 401 {
                    if let jwt = LocalUserProfile.instance().jwt(), !jwt.isEmpty {
                        self.waitingForNewAuthTokens = true
                        UploadTask.sWaitingForNewAuthTokens = true
                        PostMaster.sharedInstance().cancelAllPendingTasks()

                        weak var weakSelf = self
                        ClientToServer.instance().refreshJWT { _ in
                            DispatchQueue.main.async {
                                DDLogDebug("JWT refreshed \(String(describing: weakSelf))")
                                UploadTask.repostPendingPostsIfNeeded()
                                weakSelf?.restartIfNeeded()
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            if self.waitingForNewAuthTokens {
                                self.onError?(NSError(domain: "DMZUploadTaskError", code: 666, userInfo: nil))
                            }
                        }
                    } else {
                        DDLogWarn("Force disconnect due to the need to upate session token.")
                        ClientToServer.instance().disconnect()
                        PostMaster.sharedInstance().cancelAllPendingTasks()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ClientToServer.instance().connect()
                        }
                        UploadTask.sWaitingForNewAuthTokens = true
                    }
                } else if httpResponse?.statusCode == 429 {
                    self.onError?(NSError(domain: "DMZUploadTaskError", code: 0, userInfo: nil))
                } else {
                    self.onError?(NSError(domain: "DMZUploadTaskError", code: 666, userInfo: nil))
                }
            }
        } else {
            DDLogError("Upload <\(Unmanaged.passUnretained(self).toOpaque())> failed with error: \(String(describing: error))")
            self.onError?(error!)
        }
    }

    // MARK: - Repost

    class func repostPendingPostsIfNeeded() {
        if UploadTask.sWaitingForNewAuthTokens {
            UploadTask.sWaitingForNewAuthTokens = false
            DataProvider.instance().findPendingPostsAndRepost()
        }
    }

    // MARK: - ClientToServerDelegate

    func clientIsLoggedIn() {
        UploadTask.repostPendingPostsIfNeeded()
    }

    // MARK: - URLSession Delegates

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogDebug("task \(self) didCompleteWithError: \(String(describing: error))")
        DispatchQueue.main.async {
            if task != self.uploadTask {
                DDLogWarn("no expected task \n\(task)\n\(String(describing: self.uploadTask))")
                return
            }
            self.didFinish(with: error)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        #if !APP_STORE_MODE
        DDLogDebug("didReceiveData \(data.count)")
        #endif
        responseData.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Default handling
        return (.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive response: HTTPURLResponse) async {
        DDLogDebug("didReceiveInformationalResponse \(response.statusCode)")
        self.response = response
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        let prog = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            if self.totalBytes != totalBytesExpectedToSend {
                self.totalBytes = totalBytesExpectedToSend
                self.progress.totalUnitCount = self.totalBytes
            }
            self.progress.completedUnitCount = totalBytesSent
            self.onProgress?(prog)
            #if !APP_STORE_MODE
            DDLogDebug("didSendBodyData \(prog)")
            #endif
        }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogError("didBecomeInvalidWithError \(String(describing: error))")
        DispatchQueue.main.async {
            self.didFinish(with: error ?? NSError(domain: "DMZUploadTaskError", code: 666, userInfo: nil))
        }
    }

    // MARK: - Deinit

    deinit {
        ClientToServer.instance().removeDelegate(self)
    }
}
