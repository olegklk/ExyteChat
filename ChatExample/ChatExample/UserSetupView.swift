import SwiftUI

struct UserSetupView: View {
    @State private var veroEmail: String = ""
    @State private var veroPassword: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var navigationPath = NavigationPath()
    private let defaults = UserDefaults.standard

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section {
                    Text("E-mail:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    TextField("Email", text: $veroEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Password:")
                        .font(.headline)
                        .foregroundColor(.secondary)
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
                }
            }
            .navigationTitle("Vero Login")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AppScreen.self) { destination in
                switch destination {
                case .chatList:
                    ConversationListView(navigationPath: $navigationPath)
                default:
                    Text("Unknown destination")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear(perform: setup)
    }
    
    private func setup() {
        let credential = KeychainHelper.standard.read(service: .credential, type: VeroLoginData.self)
        veroEmail = credential?.email ?? ""
        veroPassword = credential?.password ?? ""
    }
    
    private func handleVeroLogin() async {
        let util = VeroUtility()
        let result = await util.veroLogin(username: veroEmail, password: veroPassword)
        switch result {
            case .success(let resp):
                if let token = resp.veroPass?.jwt {
                    KeychainHelper.standard.save(resp, service: .token)
                    KeychainHelper.standard.save(VeroLoginData(email: veroEmail, password: veroPassword),
                                                 service:
                            .credential)
                    
                    navigationPath.append(AppScreen.chatList)
                }
            case .failure(let error): // Show
                print("Login error\(error.localizedDescription)")
        }
                   
        await MainActor.run { isLoggingIn = false }
    }
}

//на этой странице возникает какая-то проблема с constraints в тот момент когда поле email получает фокус AI!
