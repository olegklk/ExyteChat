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
                    //добавь первым элементом в списке участников неудаляемый элемент - который будет изображать текущего игрока. Обозначь его "You (здесь помести значение из Store.userId())" AI!
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
                    .disabled(disableAddParticipant)
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
                NavigationLink(destination: startChatDestination()) {
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

    private var disableAddParticipant: Bool {
        let pid = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return pid.isEmpty || participants.contains(pid)
    }

    @ViewBuilder
    private func startChatDestination() -> some View {
        let conversation = Store.createConversation(type: chatType.rawValue, participants: participants, title: nil)
        ConversationView(viewModel: ConversationViewModel(conversationId: conversation.id, batchId: nil), title: conversation.title)
    }
}
