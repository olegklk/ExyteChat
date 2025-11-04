import SwiftUI
import ExyteChat

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
    
    @State private var debounceTask: Task<Void, Never>?
    @State private var conversationURL: String = ""
    @State private var conversationId: String?
    @State private var batchId: String?
    
    // helper to render full name
    private func displayName(_ c: Contact) -> String {
        return Store.displayName(fName: c.firstname, lName: c.lastname)
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
                            ExyteChat.ActivityIndicator()
                                .frame(width: 20, height: 20)
                                .padding(.leading, 8)
                        }
                    }
                }
                .disabled(participants.count < 2)
            }
            Section {
                VStack {
                    Text("Insert conversation URL to join:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $conversationURL)
                            .frame(minHeight: 40, maxHeight: 200)
                            .padding(4)
                            .onChange(of: conversationURL) { oldValue, newValue in
                                debounceConversationIdChange(newValue: newValue)
                            }
                        
                        if conversationURL.isEmpty {
                            Text("http://..")
                                .foregroundColor(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
//                        NavigationLink("Join conversation", value: Route.join)
                    
                    Button("Join conversation") { //Button instead of NavigationLink because this way it performs only on click and allows to set some values before navigation
                        if let conversationId, let batchId {
                            var conversation = Store.ensureConversation(conversationId)
                            conversation.batchId = batchId
                            
                            navigationPath.append(NavigationItem(screenType: AppScreen.chat, conversation:conversation))
                        }
                    }
                    .disabled(conversationId == nil || conversationURL.isEmpty)
                    
                    
                }
            } header: {
                VStack {
                    Text("Or")
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity)
                }
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

    private func debounceConversationIdChange(newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                let (convId, bId) = ChatUtils.idsFromURLString(newValue)
                if convId != nil {conversationId = convId}
                if bId != nil {batchId = bId}
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
