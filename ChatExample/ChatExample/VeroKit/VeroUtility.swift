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

import SwiftUI

class VeroUtility {
    
    let veroAuthenticationService = VeroAuthenticationService.shared
    
    func veroLogin() async -> Result<CompleteLoginResponse, VeroServiceError> {
        
        let veroLoginData = KeychainHelper2.retrieve(type: VeroLoginData.self)
        
        guard
            let username = veroLoginData?.email,
            let password = veroLoginData?.password
        else {
            return .failure(.unknown)
        }
        
        return await veroLogin(username: username, password: password)
    }
    
    func veroLogin(username: String, password: String) async -> Result<CompleteLoginResponse, VeroServiceError> {
        
        do {
            let response = try await veroAuthenticationService.loginToVero(email: username, password: password)
            return .success(response)
        } catch let error as VeroServiceError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }
    
    func configVeroInfo(forUserID userID: String, username: String, accessToken: String, clientProxy: ClientProxyProtocol) async {
        
        let profile = await veroAuthenticationService.getUserProfile(forID: userID, username: username, accessToken: accessToken)
        let contacts = await veroAuthenticationService.getContacts(accessToken)
        
        let databaseRequest = DatabaseRequest()
        Task {
            databaseRequest.addUserProfile(profile)
            databaseRequest.addContacts(contacts)
        }
        
        if let username = profile?.username {
            let _ = await clientProxy.setUserDisplayName(username)
        }
        
        if let imageURL = profile?.picture {
            await setUserAvatar(imageURL: imageURL, clientProxy: clientProxy)
        }
    }
    
    func getImage(_ imageURL: URL) async -> Image? {
        
        let request = URLRequest(url: imageURL)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               (200...299).contains(statusCode) {
                
                guard
                    let uiImage = UIImage(data: data)
                else {
                    return nil
                }
                
                let image = Image(uiImage: uiImage)
                return image
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    func getID(fromString string: String) -> String {
        
        let removedMatrixString = string.replacingOccurrences(of: ":matrix.metapolitan.io", with: "")
        let id = removedMatrixString.replacingOccurrences(of: "@", with: "")
        
        return id
    }
    
    func needToUpdateName(_ name: String) -> Bool {
        
        if name.contains(":matrix.metapolitan.io") {
            return true
        } else {
            return false
        }
    }
    
    private func setUserAvatar(imageURL: String, clientProxy: ClientProxyProtocol) async {
        
        if let mediaInfo = await getUserAvatarMediaInfo(imageURL: imageURL) {
            let _ = await clientProxy.setUserAvatar(media: mediaInfo)
        }
    }
    
    private func getUserAvatarMediaInfo(imageURL: String) async -> MediaInfo? {
        
        guard
            let url = URL(string: imageURL)
        else {
            return nil
        }
        
        let request = URLRequest(url: url)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               (200...299).contains(statusCode) {
                
                let fileName = getDocumentsDirectory().appendingPathComponent("avatar.jpeg")
                try data.write(to: fileName)
                
                let mediaPreprocessor = MediaUploadingPreprocessor()
                let mediaResult = await mediaPreprocessor.processMedia(at: fileName)
                
                switch mediaResult {
                case .success(.image):
                    
                    let mediaInfo = try mediaResult.get()
                    return mediaInfo
                default:
                    return nil
                }
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
