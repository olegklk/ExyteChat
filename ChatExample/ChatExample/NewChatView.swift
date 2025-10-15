import SwiftUI

struct NewChatView: View {
    private enum ChatType: String, CaseIterable {
        case direct = "direct"
        case group = "group"
    }
    @Binding var navigationPath: NavigationPath
    @State private var chatType: ChatType = .direct
    @State private var participantInput: String = ""
    private var currentUserId: String { Store.getSelfProfile()?.id ?? "" }
    @State private var participants: [Contact] = []
    @State private var showVeroContacts = false
    // helper to render full name
    private func displayName(_ c: Contact) -> String {
        "\(c.firstname) \(c.lastname ?? "")".trimmingCharacters(in: .whitespaces)
    }
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
                        if pid != currentUserId,
                           !participants.contains(where: { $0.id == pid }),
                           let contact = Store.getContacts().first(where: { $0.id == pid }) {
                            participants.append(contact)
                        }
                        participantInput = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(disableAddParticipant)
                }
                
                ForEach(participants, id: \.id) { contact in
                    if contact.id == currentUserId {
                        VStack(alignment: .leading) { // Non-removable current user row
                            Text("\(displayName(contact)) (You)")
                            if let username = contact.username, !username.isEmpty {
                                Text("@\(username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(displayName(contact))
                                if let username = contact.username, !username.isEmpty {
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                participants.removeAll { $0.id == contact.id }
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
                            await viewModel.start(chatType: chatType.rawValue, participants: participants.map { $0.id })
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
            if let p = Store.getSelfProfile() {
                let selfContact = Contact(id: p.id, username: p.username, firstname: p.firstName, lastname: p.lastName, picture: p.picture)
                participants = [selfContact]
            }
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
                if selectedId != currentUserId,
                   !participants.contains(where: { $0.id == selectedId }),
                   let contact = Store.getContacts().first(where: { $0.id == selectedId }) {
                    participants.append(contact)
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
        return pid.isEmpty || pid == currentUserId || participants.contains(where: { $0.id == pid })
    }

}
