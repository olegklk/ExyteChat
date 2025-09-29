import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    private enum Route: Hashable { case content }
    @State private var path = NavigationPath()
    private let defaults = UserDefaults.standard
    private let userIdKey = "UserSettings.userId"
    private let userNameKey = "UserSettings.userName"

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter Your Name:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    
                TextField("Your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("UserId:")
                    .font(.headline)
//                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
                
                TextField("UserId:", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Spacer()
            }
            .padding()
//            .navigationTitle("User Creation")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Go") {
                        save()
                        path.append(Route.content)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .content:
                    ContentView()
                }
            }
        }
        .onAppear(perform: setup)
    }

    private func setup() {
        if let savedId = defaults.string(forKey: userIdKey) {
            userId = savedId
        } else {
            let newId = generateRandomUserId()
            userId = newId
            defaults.set(newId, forKey: userIdKey)
        }
        name = defaults.string(forKey: userNameKey) ?? ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: userNameKey)
        defaults.set(userId, forKey: userIdKey)
        
    }

    private func generateRandomUserId() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomPart = String((0..<8).compactMap { _ in alphabet.randomElement() })
        return "u:" + randomPart
    }
}
