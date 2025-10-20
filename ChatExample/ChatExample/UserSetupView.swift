import SwiftUI

struct UserSetupView: View {
    @State private var veroEmail: String = ""
    @State private var veroPassword: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedEnv: VeroEnvironment = EnvironmentConstants.currentEnvironment()
    private let defaults = UserDefaults.standard

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section(header: Text("Environment")) {
                    Picker("Environment", selection: $selectedEnv) {
                        ForEach(VeroEnvironment.allCases, id: \.self) { env in
                            Text(env.rawValue.capitalized).tag(env)
                        }
                    }
                    .pickerStyle(.menu)
                }
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
            .onChange(of: selectedEnv) { _, newValue in
                VeroAuthenticationService.shared.selectEnvironment(newValue)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear(perform: setup)
    }
    //добавь на этом экране дополнительное красное текстовое поле под формой в котором будет показываться VeroAuthenticationService.userFacingError если возникнет AI!
    
    private func setup() {
        
        let credential = KeychainHelper.standard.read(service: .credential, type: VeroLoginData.self)
        veroEmail = credential?.email ?? ""
        veroPassword = credential?.password ?? ""
        selectedEnv = EnvironmentConstants.currentEnvironment()
    }
    
    private func handleVeroLogin() async {
        let util = VeroUtility()
        let result = await util.veroLogin(username: veroEmail, password: veroPassword)
        switch result {
            case .success(let resp):
                if let accessToken = resp.veroPass?.jwt,
                    let userID = resp.userID {
                        await util.configVeroInfo(forUserID: userID, email: veroEmail, accessToken: accessToken)
                    
                    navigationPath.append(AppScreen.chatList)
                }
            case .failure(let error): // Show
                print("Login error\(error.localizedDescription)")
        }
                   
        await MainActor.run { isLoggingIn = false }
    }
}
