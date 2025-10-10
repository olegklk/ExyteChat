import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var navigationPath = NavigationPath()
    private let defaults = UserDefaults.standard

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter Your Name:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    
                TextField("Your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("UserId:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("User Id", text: $userId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Spacer()
            }
            .padding()
            .navigationTitle("User Creation")
            .navigationDestination(for: AppScreen.self) { destination in
                switch destination {
                    case .chatList:
                        ConversationListView(navigationPath:$navigationPath)
                default:
                    Text("Unknown destination")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Go") {
                        save()
                        navigationPath.append(AppScreen.chatList)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        
        .onAppear(perform: setup)
    }
    
    private func setup() {
        userId = Store.userId()
        name = Store.userName()
    }
    
    private func save() {
        Store.persistUserName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        Store.persistUserId(userId.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
