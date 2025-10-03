import SwiftUI

struct NewChatView: View {
    private enum ChatType: String, CaseIterable {
        case direct = "direct"
        case group = "group"
    }
    @State private var conversationId: String = ""
    @State private var chatType: ChatType = .direct
    @State private var participantInput: String = ""
    @State private var participants: [String] = []
    //проверь body ниже на предмет корректности потому что я вижу ошибку компилятора The compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions нет ли там видимых проблем AI!
    var body: some View {
        Form {
            Section(header: Text("Chat Type")) {
//                TextField("Conversation ID", text: $conversationId)
//                    .textInputAutocapitalization(.never)
//                    .autocorrectionDisabled(true)

                Picker("Chat type", selection: $chatType) {
                    Text("direct").tag(ChatType.direct)
                    Text("group").tag(ChatType.group)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Participants")) {
                HStack {
                    TextField("Insert participant Id", text: $participantInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button {
                        let pid = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !pid.isEmpty else { return }
                        if !participants.contains(pid) {
                            participants.append(pid)
                        }
                        participantInput = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled({
                        let pid = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        return pid.isEmpty || participants.contains(pid)
                    }())
                }
                
                ForEach(participants, id: \.self) { pid in
                    HStack {
                        Text(pid)
                        Spacer()
                        Button {
                            participants.removeAll { $0 == pid }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                NavigationLink(destination: {
                    let conversationId =  ChatUtils.generateRandomConversationId()
                    
                    Store.ensureConversation(conversationId)
                    var conversation = Store.conversation(for: conversationId)
                    conversation.type = chatType.rawValue
                    
                    let vm = ConversationViewModel(conversationId: conversationId)
                    return ConversationView(viewModel: vm, title: "")
                }()) {
                    Text("Start chat")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(participants.isEmpty)
            }
        }
        .navigationTitle("New Chat")
        .onAppear {
            if conversationId.isEmpty {
                conversationId = generateConversationId()
            }
        }
        .onChange(of: participants) { newValue in
            if newValue.count > 1 {
                chatType = .group
            }
        }
    }

    private func generateConversationId() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomPart = String((0..<10).compactMap { _ in alphabet.randomElement() })
        return "c:\(randomPart)"
    }
}
