import SwiftUI

struct NewChatView: View {
    private enum ChatType: String, CaseIterable {
        case direct = "direct"
        case group = "group"
    }
    
    @State private var chatType: ChatType = .direct
    @State private var participantInput: String = ""
    private var currentUserId: String { Store.userId() }
    @State private var participants: [String] = [Store.userId()]
    private var currentUserName: String { Store.userName() }
    var body: some View {
        Form {
            Section(header: Text("Chat Type")) {
                Picker("Chat type", selection: $chatType) {
                    if participants.count <= 2 {
                        Text("direct").tag(ChatType.direct)
                    }
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
                    .disabled(disableAddParticipant)
                }
                
                ForEach(participants, id: \.self) { pid in
                    if pid == currentUserId {
                        HStack {// Non-removable current user row
                            Text("You (\(currentUserName) \(currentUserId))")
                            Spacer()
                        }
                    } else {
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
            }

            Section {
                NavigationLink(destination: startChatDestination()) {
                    Text("Start chat")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(participants.count < 2)
            }
        }
        .navigationTitle("New Chat")
        .onAppear {
            
        }
        .onChange(of: participants) { newValue in
            if newValue.count > 2 {
                chatType = .group
            }
        }
    }

    private var disableAddParticipant: Bool {
        let pid = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return pid.isEmpty || pid == currentUserId || participants.contains(pid)
    }

    @ViewBuilder
    private func startChatDestination() -> some View {
        let allParticipants = Array(Set([currentUserId] + participants))
        ConversationView(viewModel: ConversationViewModel(conversationId: nil, batchId: nil, participants: allParticipants), title: conversation.title)
    }
}
