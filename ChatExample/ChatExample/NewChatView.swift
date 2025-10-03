import SwiftUI

struct NewChatView: View {
    @State private var conversationId: String = ""
    @State private var chatType: String = "direct"

    //добавь в интерфейс еще одну группу настроек - выбор участников. Это должно быть текстовое поле ввода в котором будет placeholder "Insert participant Id" и при вводе нового userId активируется кнопка добавить, после чего новый userId появляется ниже в виде List. При этом каждый элемент в этом List имеет кнопку с иконкой trash can при нажатии на которую элемент удаляется из списка AI!
    
    var body: some View {
        Form {
            Section(header: Text("Chat Type")) {
//                TextField("Conversation ID", text: $conversationId)
//                    .textInputAutocapitalization(.never)
//                    .autocorrectionDisabled(true)

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
