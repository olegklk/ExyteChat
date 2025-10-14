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
                                                                                                     
    func veroLogin(username: String, password: String) async -> Result<CompleteLoginResponse,
VeroServiceError> {
                                                                                                     
        do {
            let response = try await veroAuthenticationService.loginToVero(email: username, password:
password)
            return .success(response)
        } catch let error as VeroServiceError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }
}       
