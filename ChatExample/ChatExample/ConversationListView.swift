import SwiftUI
import ExyteChat

struct ConversationListView: View {
    
    @StateObject private var viewModel : ConversationListViewModel = ConversationListViewModel()
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.exampleBlue)
    
    @State private var conversationURL: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    @State private var conversationId: String?
    @State private var batchId: String?
    
    var body: some View {
        NavigationView {
            List {
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
                                            
                        NavigationLink(String("Join conversation")) {
                            if let convId = conversationId {
                                destinationView(for: convId)
                            }
                        }.disabled(conversationId == nil || conversationURL.isEmpty)
                    }
                } header: {
                    Text("Join by URL")
                }

                Section {
                    VStack {
                        NavigationLink(destination: NewChatView()) {
//                            Image(systemName: "plus")
                            Text("Create New Chat")
                        }
                    }
                } header: {
                    Text("")
                }
                Section {
                    ForEach(
                        viewModel.conversationItems.sorted { $0.latestUnreadStartedAt > $1.latestUnreadStartedAt },
                        id: \.conversationId
                    ) { item in
                        HStack {
                            NavigationLink(String(item.conversationId.prefix(10))) {
                                if !theme.isAccent, #available(iOS 18.0, *) {
                                    ConversationView(viewModel: ConversationViewModel(conversationId: item.conversationId), title: String(item.conversationId.prefix(10)))
                                        .chatTheme(themeColor: color)
                                } else {
                                    ConversationView(viewModel: ConversationViewModel(conversationId: item.conversationId), title: String(item.conversationId.prefix(10)))
                                        .chatTheme(
                                            accentColor: color,
                                            images: theme.images
                                        )
                                }
                                
                            }
                            Spacer()
                            Text("\(item.unreadCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Chats")
                }
            }
            .navigationTitle("Chats ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(theme.title) {
                            theme = theme.next()
                        }
                        ColorPicker("", selection: $color)
                    }
                }
            }
            .onAppear(perform: setup)
            
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder
    private func destinationView(for convId: String) -> some View {
        let vm = ConversationViewModel(conversationId: convId)
        if let batchId { vm.batchId = batchId }
        let title = String(convId.prefix(10))
        if !theme.isAccent, #available(iOS 18.0, *) {
            ConversationView(viewModel: vm, title: title)
                .chatTheme(themeColor: color)
        } else {
            ConversationView(viewModel: vm, title: title)
                .chatTheme(
                    accentColor: color,
                    images: theme.images
                )
        }
    }
    
    private func setup() {
        
        viewModel.onAppear()
        
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
}

/// An enum that lets us iterate through the different ChatTheme styles
enum ExampleThemeState: String {
    case accent
    case image
    
    @available(iOS 18, *)
    case themed
    
    var title:String {
        self.rawValue.capitalized
    }
    
    func next() -> ExampleThemeState {
        switch self {
        case .accent:
            if #available(iOS 18.0, *) {
                return .themed
            } else {
                return .image
            }
        case .themed:
            return .image
        case .image:
            return .accent
        }
    }
    
    var images: ChatTheme.Images {
        switch self {
        case .accent, .themed: return .init()
        case .image:
            return .init(
                background: ChatTheme.Images.Background(
                    portraitBackgroundLight: Image("chatBackgroundLight"),
                    portraitBackgroundDark: Image("chatBackgroundDark"),
                    landscapeBackgroundLight: Image("chatBackgroundLandscapeLight"),
                    landscapeBackgroundDark: Image("chatBackgroundLandscapeDark")
                )
            )
        }
    }
    
    var isAccent: Bool {
        if #available(iOS 18.0, *) {
            return self != .themed
        }
        return true
    }
}


