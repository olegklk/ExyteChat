//
// Copyright 2024 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import SRP
import CryptoKit
import ChatAPIClient

@objc public enum AccessTokenStatus: Int {
    // first three cases are for logged in user
    case valid = 0 // valid token
    case expired // token expired
    case authenticating // authentication in process
    case prelogin // user is logged out
}
enum VeroEnvironment: String, CaseIterable {
    case production
    case staging
    
    var baseURL: String {
        switch self {
        case .production: return "https://gateway.veroapi.com"
        case .staging:    return "https://gateway-stg.veroapi.com"
        }
    }
    var uploadURL: String {
        switch self {
            case .production : return "https://gateway.veroapi.com/content-upload"
            case .staging: return "https://gateway-stg.veroapi.com/content-upload"
        }
    }
}
struct EnvironmentConstants {
    private static let key = "vero.environment"
    
    static func setEnvironment(_ env: VeroEnvironment) {
        UserDefaults.standard.set(env.rawValue, forKey: key)
    }
    
    static func currentEnvironment() -> VeroEnvironment {
        if let raw = UserDefaults.standard.string(forKey: key),
           let env = VeroEnvironment(rawValue: raw) {
            return env
        }
        return .staging
    }
    
    static func currentBaseURL() -> String {
        currentEnvironment().baseURL
    }
    
    static func currentUploadURL() -> String {
        currentEnvironment().uploadURL
    }
}

enum VeroServiceError: Error, LocalizedError, CustomStringConvertible {
    case challenge
    case complete
    case refresh
    case urlNill
    case saveData
    case tokenBase
    case restoreSession
    case unknown
    case internalError
    
    var errorDescription: String? {
        return self.description
    }
    
    var description: String {
        switch self {
        case .challenge:        return "Error in calling challenge service"
        case .complete:         return "Error in calling complete service"
        case .refresh:          return "Error in calling refresh service"
        case .urlNill:          return "The URL is Nill"
        case .saveData:         return "Error in saving data"
        case .tokenBase:        return "Error in calling token based login service"
        case .restoreSession:   return "Error in restoring session"
        case .unknown:          return "UnKnown error"
        case .internalError:         return "Internal server error"
        }
    }
}

final class VeroAuthenticationService: ObservableObject, @unchecked Sendable {
    static let error = NSError(domain: "Networking", code: 0, userInfo: [NSLocalizedDescriptionKey : "Networking Error"])
    var isRefreshingToken = false
    @objc public var tokenStatus: AccessTokenStatus = .prelogin
    @Published var userFacingError: VeroServiceError?
    private let retryInterval: TimeInterval = 3
    static let shared = VeroAuthenticationService()
    public func selectEnvironment(_ env: VeroEnvironment) {
        EnvironmentConstants.setEnvironment(env)
    }
    
    enum FBURL {
        case loginToVero
        case completeLogin
        case refresh
        case profile
        
        var url: String {
            let base = EnvironmentConstants.currentBaseURL()
            switch self {
            case .loginToVero:
                return base + "/api/auth/challenge"
            case .completeLogin:
                return base + "/api/auth/complete"
            case .refresh:
                return base + "/veritas/refresh"
            case .profile:
                return base + "/api/profiles/self"
            }
            
        }
    }
    
    private init() {}
    
    private func veroBaseComponents() -> URLComponents {
        URLComponents(string: EnvironmentConstants.currentBaseURL()) ?? URLComponents()
    }
    
    private func delay(_ interval: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) // Convert seconds to nanoseconds
    }
    
    func sendRequest(url: URL,
                     httpMethod: String = "POST",
                     timeout: TimeInterval? = nil,
                     numberOfRetries: Int = 2,
                     message: String? = nil,
                     body: Any? = nil,
                     skipLogs: Bool = false,
                     refreshToken: Bool = false,
                     skipAuth:Bool = false,
                     error: VeroServiceError) async throws -> (Data) {
        if let accessToken = KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt {
            tokenStatus = needRefreshToken(token: accessToken) ? .expired : .valid
            if tokenStatus == .expired && !isRefreshingToken {
                let refreshToken = try await refresh()
                if refreshToken != nil {
                    return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
                }
                else {
                    let credential = KeychainHelper.standard.read(service: .credential, type: VeroLoginData.self)
                    let _ = try await loginToVero(email: credential?.email ?? "", password: credential?.password ?? "")
                    if !url.absoluteString.contains("auth"){
                        return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
                    }
                }
            }
            else if tokenStatus == .expired && isRefreshingToken && !refreshToken {
                return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
            }
        }
//        print(currentAccessToken)
        var request = URLRequest(url: url)
     
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "accept"
        )
        request.httpMethod = httpMethod
        if let timeout = timeout {
            request.timeoutInterval = timeout
        }
        
        if httpMethod != "GET" {
            var body = body
            if let message {
                body = ["message": message]
            }
            if let body {
                let bodyData = try? JSONSerialization.data(
                    withJSONObject: body,
                    options: []
                )
                request.httpBody = bodyData
            }
        }
        
        let session = URLSession.shared
        
        do {
            if !self.isRefreshingToken || refreshToken {
                let (data, response) = try await session.data(for: request)
//                print("RESPONSE: \(String(data: data, encoding: .utf8) ?? "")")
                if !skipLogs {
                 
                }
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 500 {//internal error
                        throw VeroServiceError.internalError
                    }
                    else if statusCode == 401 || statusCode == 403 {
                        tokenStatus = .expired
                        return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
                    }
                    else if statusCode >= 200, statusCode <= 299 {
                        return data
                    }
                }
                else
                {
                    return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
                }
            }
            return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error)
        } catch let error {
            switch error {
                case VeroServiceError.internalError:
                    await MainActor.run {
                        self.userFacingError = VeroServiceError.internalError
                    }
                    throw VeroServiceError.internalError
                default:
                    return try await retry(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries, message: message, body: body, skipLogs: skipLogs, error: error as! VeroServiceError)
            }
            
        }
    }
    
    private func retry(url: URL, httpMethod: String, timeout: TimeInterval?, numberOfRetries: Int, message: String?, body: Any?, skipLogs: Bool, error: VeroServiceError) async throws -> (Data) {
        if numberOfRetries <= 0 {
            throw error
        } else {
            
            try await delay(retryInterval)
            return try await self.sendRequest(url: url, httpMethod: httpMethod, timeout: timeout, numberOfRetries: numberOfRetries - 1, message: message, body: body, skipLogs: skipLogs, error: error)
        }
    }
}

extension VeroAuthenticationService {
    
    func loginToVero(email: String, password: String) async throws -> CompleteLoginResponse {
        if !self.isRefreshingToken {
            self.isRefreshingToken = true
            let srpClient = SRPClient(configuration: SRPConfiguration<SHA256>(.N1024))
            var clientKeys: SRPKeyPair?
            clientKeys = srpClient.generateKeys()
            let clientPublicKey = clientKeys!.public.hex
            let body = ["clientPub": clientPublicKey, "login": email]
            
            if let url = URL(string: FBURL.loginToVero.url) {
                let result = try await sendRequest(url: url, numberOfRetries: 5, body: body, refreshToken: true, skipAuth: true, error: .challenge)
                let decoder = JSONDecoder()
                let response = try decoder.decode(ChallengeTokenResponse.self, from: result)
                
                if let salt = response.salt, let serverPub = response.serverPub {
                    guard let saltBytes = dataFromHex(salt),
                          let serverPubKey = SRPKey(hex: serverPub) else {
                        throw VeroServiceError.challenge
                    }
                    
                    let clientSharedSecret = try srpClient.calculateSharedSecret(
                        username: email,
                        password: password,
                        salt: [UInt8](saltBytes),
                        clientKeys: clientKeys!,
                        serverPublicKey: serverPubKey
                    )
                    
                    let clientProof = srpClient.calculateClientProof(
                        username: email,
                        salt: [UInt8](saltBytes),
                        clientPublicKey: clientKeys!.public,
                        serverPublicKey: serverPubKey,
                        sharedSecret: clientSharedSecret
                    )
                    
                    let proofString = hexFromBytes(clientProof)
                    return try await completeVeroLogin(email: email, password: password, proofString: proofString)
                }
                throw VeroServiceError.challenge
            } else {
                throw VeroServiceError.challenge
            }
        }
        throw VeroServiceError.challenge
    }
    
    func completeVeroLogin(email: String, password: String, proofString: String) async throws -> CompleteLoginResponse {
        let body = ["origin": "vero_social", "login": email, "clientProof": proofString, "device" : [
             "type": "ios",
             "version": "1",
             "os": "17.4",
             "name": "iPhone 14"
        ]] as [String : Any]
        if let url = URL(string: FBURL.completeLogin.url) {
            let result = try await sendRequest(url: url, numberOfRetries: 5, body: body, refreshToken: true, skipAuth: true, error: .complete)
            let decoder = JSONDecoder()
            let response = try decoder.decode(CompleteLoginResponse.self, from: result)
            if let _ = response.veroPass?.jwt {
                KeychainHelper.standard.delete(service: .token)
                KeychainHelper.standard.save(response, service:.token)
                KeychainHelper.standard.save(VeroLoginData(email: email, password: password), service: .credential)
                
                _ = KeychainHelper.standard.read(service: .credential, type: VeroLoginData.self)
                
                Task {
                    await ChatAPIClient.shared.setTokenProvider {
                        KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt
                    }
                    await SocketIOManager.shared.setTokenProvider {
                        KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt
                    }
                }
                
                self.isRefreshingToken = false
                return response
            }
            throw VeroServiceError.complete
        } else {
            throw VeroServiceError.complete
        }
    }
    
    func refresh() async throws -> RefreshTokenResponse? {
        do {
            if let url = URL(string: FBURL.refresh.url) {
                if !self.isRefreshingToken
                {
                    self.isRefreshingToken = true
                    var credential = KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)
                    guard let did = credential?.veroPass?.refresh?.did, let tok = credential?.veroPass?.refresh?.tok else { return nil }
                    let body = ["uid": credential?.userID, "did": did,"tok":tok]
                    let data = try await sendRequest(url: url, numberOfRetries: 5, body: body, refreshToken: true, skipAuth: true, error: .refresh)
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(RefreshTokenResponse.self, from: data)
                    credential?.veroPass?.refresh?.did = response.refresh?.did
                    credential?.veroPass?.refresh?.tok = response.refresh?.tok
                    credential?.veroPass?.refresh?.exp = response.refresh?.exp
//                    let email = UsersLocalStorageManager.shared.getVeroEmail()
//                    UsersLocalStorageManager.shared.setVeroAuth(token: response.jwt ?? "", email: email ?? "")
                    KeychainHelper.standard.save(credential, service: .token)
                    Task {
                        await ChatAPIClient.shared.setTokenProvider {
                            KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt
                        }
                        await SocketIOManager.shared.setTokenProvider {
                            KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt
                        }
                    }
                    self.isRefreshingToken = false
                    return response
                }
            } else {
                throw VeroServiceError.urlNill
            }
        }
        catch {
            self.isRefreshingToken = false
        }
        return nil
    }
    
     func needRefreshToken(token: String) -> Bool {
        guard let exp = jwtExpiration(token) else { return true }
        return Date(timeIntervalSince1970: exp) <= Date()
    }
}
private func dataFromHex(_ hex: String) -> Data? {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "0x", with: "")
    guard cleaned.count % 2 == 0 else { return nil }
    var data = Data()
    data.reserveCapacity(cleaned.count / 2)
    var i = cleaned.startIndex
    while i < cleaned.endIndex {
        let j = cleaned.index(i, offsetBy: 2)
        guard let b = UInt8(cleaned[i..<j], radix: 16) else { return nil }
        data.append(b)
        i = j
    }
    return data
}
private func hexFromBytes(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}
private func base64urlDecode(_ str: String) -> Data? {
    var s = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let pad = 4 - (s.count % 4)
    if pad < 4 { s += String(repeating: "=", count: pad) }
    return Data(base64Encoded: s)
}
private func jwtExpiration(_ token: String) -> TimeInterval? {
    let parts = token.split(separator: ".")
    guard parts.count == 3,
          let payload = base64urlDecode(String(parts[1])),
          let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
          let exp = json["exp"] as? Double else { return nil }
    return exp
}

////MARK: - plist manager
//struct PlistManager {
//    
//    let fileURL = try? FileManager.default
//        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//        .appendingPathComponent("Contacts.plist")
//    
//    func readContacts() -> [Contact] {
//        
//        do {
//            guard
//                let fileURL
//            else {
//                print("can't find Contacts.plist file")
//                return []
//            }
//            
//            let data = try Data(contentsOf: fileURL)
//            let contacts = try PropertyListDecoder().decode([Contact].self, from: data)
//            return contacts
//        } catch {
//            print(error)
//            return []
//        }
//    }
//    
//    func saveContacts(_ contacts: [Contact]?) {
//        
//        do {
//            guard
//                let fileURL
//            else {
//                print("can't find Contacts.plist file")
//                return
//            }
//
//            let data = try PropertyListEncoder().encode(contacts)
//            try data.write(to: fileURL)
//        } catch {
//            print(error)
//        }
//    }
//    
//    func deleteContacts() {
//        
//        guard
//            let fileURL
//        else {
//            print("can't find Contacts.plist file")
//            return
//        }
//        
//        do {
//            try FileManager.default.removeItem(at: fileURL)
//        } catch {
//            print(error)
//        }
//    }
//}
