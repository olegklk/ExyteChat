import SwiftUI

struct UserSetupView: View {
    @State private var name: String = ""
    @State private var userId: String = ""
        
    private let defaults = UserDefaults.standard

    var body: some View {
        NavigationView {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Go") {
                        destinationView()
                    }
                    .simultaneousGesture(TapGesture().onEnded { save() })
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
    
    private func destinationView() -> AnyView{
        return AnyView(ConversationListView())
    }

    private func save() {
        Store.persistUserName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        Store.persistUserId(userId.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
