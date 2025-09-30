import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    
    @State private var conversationURL: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    @State private var conversationId: String = ""
    @State private var batchId: String?
    private enum Route: Hashable { case content }
    @State private var path = NavigationPath()
    private let defaults = UserDefaults.standard

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
                
                TextField("User Id", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Insert conversation URL to join:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
//                TextField("", text: $conversationURL)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .onChange(of: conversationURL) { oldValue, newValue in
//                        debounceConversationIdChange(newValue: newValue)
//                                        }
                TextEditor(text: $conversationURL)
                                    .frame(minHeight: 40, maxHeight: 200)
                                    .padding(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: conversationURL) { oldValue, newValue in
                                        debounceConversationIdChange(newValue: newValue)
                                    }

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
        .onReceive(NotificationCenter.default.publisher(for: Store.conversationIdDidChange)) { _ in
            conversationURL = Store.conversationURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: Store.batchIdDidChange)) { _ in
            conversationURL = Store.conversationURL()
        }
    }
    
    private func debounceConversationIdChange(newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                ChatUtils.persistIDsFromURLString(newValue)
            }
        }
    }
    
    private func setup() {
        
        userId = Store.userId()
        name = Store.userName()
        conversationId = Store.conversationId()
        if let savedId = Store.batchId()  {
            batchId = savedId
        }
        conversationURL = Store.conversationURL()
        
    }

    private func save() {

        Store.persistUserName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        Store.persistUserId(userId.trimmingCharacters(in: .whitespacesAndNewlines))
        Store.persistConversationId(conversationId.trimmingCharacters(in: .whitespacesAndNewlines))

    }
    
}
