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

// MARK: - Login
struct CompleteLoginResponse: Codable {
    var userID, serverProof: String?
    var facets: Int?
    var identityExist: Bool?
    var veroPass: VeroPass?
    var settings: Settings?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case serverProof, facets, identityExist, veroPass, settings
    }
}

// MARK: - VeroPass
struct VeroPass: Codable {
    var jwt: String?
    var refresh: Refresh?
}

// MARK: - Refresh
struct Refresh: Codable {
    var tok: String?
    var exp: Int?
    var did: String?
}

// MARK: - Settings
struct Settings: Codable {
    let nsfwFilterEnabled, nsfwFilterThreshold: String?

    enum CodingKeys: String, CodingKey {
        case nsfwFilterEnabled = "NsfwFilterEnabled"
        case nsfwFilterThreshold = "NsfwFilterThreshold"
    }
}
