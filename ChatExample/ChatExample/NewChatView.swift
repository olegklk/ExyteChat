import SwiftUI

struct NewChatView: View {
    @State private var conversationId: String = ""
    @State private var chatType: String = "direct"
    @State private var participantInput: String = ""
    @State private var participants: [String] = []
    
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
