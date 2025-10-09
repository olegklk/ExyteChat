import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
    
    
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
                
                Text("UserId:") //отмени для этого поля капитализацию AI!
                    .font(.headline)
//                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
                
                TextField("User Id", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Spacer()
            }
            .padding()
            .navigationTitle("User Creation")
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
                    ConversationListView()
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
