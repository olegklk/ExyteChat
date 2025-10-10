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
        .onChange(of: $viewModel.navigationItem) { oldValue, newValue in
            //что за ошибка здесь Instance method 'onChange(of:initial:_:)' requires that 'Binding<NavigationItem?>' conform to 'Equatable' AI!
            var conversation = newValue.conversation
            let vm = ConversationViewModel(conversation: conversation!)
            let newStack = [
                NavigationItem(screenType: .userSetup, conversation: nil),
                newValue
            ]
            navigationPath = NavigationPath(newStack)
            
        }
        .navigationDestination(for: NavigationItem.self) { item in
            conversationDestination(item: item)
        }
    }

    private func conversationDestination(item: NavigationItem) -> AnyView {
        
        switch item.screenType  {
            case .chat:
                if let conversation = item.conversation {
                    let vm = ConversationViewModel(conversation: conversation)
                    return AnyView(
                        ConversationView(viewModel: vm, path: $navigationPath)
                    )
                }
            case .userSetup:
                
                return AnyView(
                    UserSetupView()
                )
                
            case .newChat, .chatList:
                break
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
