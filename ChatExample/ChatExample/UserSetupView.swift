import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    @State private var veroEmail: String = ""
    @State private var veroPassword: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var navigationPath = NavigationPath()
    private let defaults = UserDefaults.standard

    var body: some View {
        NavigationStack(path: $navigationPath) {
            //добвиь еще один блок с вводимыми данными, где можно будет ввести Vero user email и password и кнопкой Login под ними AI!
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
                
                Divider().padding(.vertical, 4)
                Text("Vero Login:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                TextField("Email", text: $veroEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                SecureField("Password", text: $veroPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button {
                    isLoggingIn = true
                    Task { await handleVeroLogin() }
                } label: {
                    HStack {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                        if isLoggingIn {
                            ProgressView().padding(.leading, 8)
                        }
                    }
                }
                .disabled(veroEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || veroPassword.isEmpty)
                
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
    
    private func handleVeroLogin() async {
        // TODO: интегрировать VeroAuthenticationService
        await MainActor.run { isLoggingIn = false }
    }
}
