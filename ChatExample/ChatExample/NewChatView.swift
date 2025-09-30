import SwiftUI

struct NewChatView: View {
    @State private var conversationId: String = ""

    var body: some View {
        Form {
            Section(header: Text("Create new chat")) {
                TextField("Conversation ID", text: $conversationId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section {
                NavigationLink(destination: {
                    let vm = APIClientExampleViewModel()
                    return APIClientExampleView(viewModel: vm, title: "Gramatune chat (demo)")
                }()) {
                    Text("Start chat")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(conversationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("New Chat")
        .onAppear {
            if conversationId.isEmpty {
                conversationId = generateConversationId()
            }
        }
    }

    private func generateConversationId() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomPart = String((0..<10).compactMap { _ in alphabet.randomElement() })
        return "c:\(randomPart)"
    }
}
