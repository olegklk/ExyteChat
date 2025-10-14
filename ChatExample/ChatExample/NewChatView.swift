import SwiftUI

struct NewChatView: View {
    private enum ChatType: String, CaseIterable {
        case direct = "direct"
        case group = "group"
    }
    @Binding var navigationPath: NavigationPath
    
    @State private var chatType: ChatType = .direct
    @State private var participantInput: String = ""
    private var currentUserId: String { Store.userId() }
    @State private var participants: [String] = [Store.userId()]
    @State private var showVeroContacts = false
    private var currentUserName: String { Store.userName() }
    @StateObject private var viewModel = NewChatViewModel()
    
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
                Button("Add Vero Contact") {
                    showVeroContacts = true
                }
            }

            Section {
                Button(action: {
                        Task {
                            await viewModel.start(chatType: chatType.rawValue, participants: participants)
                        }
                    }) {
                    HStack {
                        Text("Start chat")
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                }
                .disabled(participants.count < 2)
            }
            
            if let error = viewModel.error {
                Section {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("New Chat")
        .onAppear {
            
        }
        .onChange(of: participants) { oldValue, newValue in
            if newValue.count > 2 {
                chatType = .group
            }
        }
        .navigationDestination(item: $viewModel.navigationItem) { item in
            conversationDestination(item: item)
        }
        .sheet(isPresented: $showVeroContacts) {
            VeroContactsView { selectedId in
                if selectedId != currentUserId && !participants.contains(selectedId) {
                    participants.append(selectedId)
                }
                showVeroContacts = false
            }
        }
    }

    private func conversationDestination(item: NavigationItem) -> AnyView {
        
        if item.screenType == .chat  {
            if let conversation = item.conversation {
                let vm = ConversationViewModel(conversation: conversation)
                return AnyView(
                    ConversationView(viewModel: vm, path: $navigationPath)
                )
            }
        }
        return AnyView(
            EmptyView()
        )
    }
    
    private var disableAddParticipant: Bool {
        let pid = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return pid.isEmpty || pid == currentUserId || participants.contains(pid)
    }

}
