import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var go = false

    private let defaults = UserDefaults.standard
    private let userIdKey = "UserSettings.userId"
    private let userNameKey = "UserSettings.userName"

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text(userId.isEmpty ? "…" : "UserId: \(userId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                NavigationLink(destination: ContentView(), isActive: $go) { EmptyView() }
            }
            .padding()
            .navigationTitle("Enter your name")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Go") {
                        save()
                        go = true
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: setup)
    }

    private func setup() {
        if let savedId = defaults.string(forKey: userIdKey) {
            userId = savedId
        } else {
            let newId = UUID().uuidString
            userId = newId
            defaults.set(newId, forKey: userIdKey)
        }
        name = defaults.string(forKey: userNameKey) ?? ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: userNameKey)
        if defaults.string(forKey: userIdKey) == nil {
            defaults.set(userId, forKey: userIdKey)
        }
    }
}
