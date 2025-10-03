import SwiftUI

struct NewChatView: View {
    @State private var conversationId: String = ""
    @State private var chatType: String = "direct"

    var body: some View {
        Form {
            Section(header: Text("Create new chat")) {
                TextField("Conversation ID", text: $conversationId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Picker("Chat type", selection: $chatType) {
                    Text("direct").tag("direct")
                    Text("group").tag("group")
                }
                .pickerStyle(.segmented)
            }

            Section {
                NavigationLink(destination: {
                    let conversationId =  ChatUtils.generateRandomConversationId()
                    
                    Store.ensureConversation(conversationId)
                    var conversation = Store.conversation(for: conversationId)
                    conversation.type = chatType
                    
                    let vm = ConversationViewModel(conversationId: conversationId)
                    return ConversationView(viewModel: vm, title: "")
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
