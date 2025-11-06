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

final class VeroAPIManager: ObservableObject, Sendable {
    static let shared = VeroAPIManager()
    
    private let baseURL: String
    
    private init() {
        self.baseURL = EnvironmentConstants.currentBaseURL()
    }
    
    /// A generic helper method to perform authenticated GET requests.
    private func performGETRequest<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String,
        responseType: T.Type
    ) async -> T? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.path = path
        components.queryItems = queryItems
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                let decodedResponse = try decoder.decode(responseType, from: data)
                return decodedResponse
            }
        } catch {
            print("API Request failed for path \(path): \(error)")
        }
        return nil
    }
    
    // MARK: - Public API Methods
    
    func getContacts(_ accessToken: String) async -> [Contact]? {
        return await performGETRequest(
            path: "/api/relations/contacts",
            accessToken: accessToken,
            responseType: [Contact].self
        )
    }
    
    func getUserProfile(forID id: String, email: String, accessToken: String) async -> SelfProfile? {
        let queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "username", value: email)
        ]
        return await performGETRequest(
            path: "/api/profiles",
            queryItems: queryItems,
            accessToken: accessToken,
            responseType: SelfProfile.self
        )
    }
    
    func getProfiles(forIDs ids: [String], accessToken: String) async -> [Profile]? {
        let queryItems = ids.map { URLQueryItem(name: "ids", value: $0) }
        let profileResponse: ProfileResponse? = await performGETRequest(
            path: "/api/profiles/list",
            queryItems: queryItems,
            accessToken: accessToken,
            responseType: ProfileResponse.self
        )
        return profileResponse?.items
    }
}

// MARK: - Data Models

public struct SelfProfile: Codable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let picture: String?
    enum CodingKeys: String, CodingKey {
        case id, username, picture
        case firstName = "firstname"
        case lastName = "lastname"
    }
}

struct ProfileResponse: Decodable {
    let items: [Profile]
}

public struct Profile: Codable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let picture: String?
    enum CodingKeys: String, CodingKey {
        case id, username, picture
        case firstName = "firstname"
        case lastName = "lastname"
    }
}
