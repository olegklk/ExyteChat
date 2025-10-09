import SwiftUI
import ChatAPIClient
import ExyteChat

struct ConversationListView: View {
    
    private enum Route: Hashable {
        case join
        case new
    }
    @State private var isFirstAppear = true
    @StateObject private var viewModel : ConversationListViewModel = ConversationListViewModel()
    
    @State private var navigationPath = NavigationPath()
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.exampleBlue)
    
    @State private var conversationURL: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    @State private var conversationId: String?
    @State private var batchId: String?
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        NavigationLink("Join conversation", value: Route.join)
                        .disabled(conversationId == nil || conversationURL.isEmpty)
                    }
                } header: {
                    Text("Join by URL")
                }

                Section {
                    VStack {
                        NavigationLink("Create New Chat", value: Route.new)
                    }
                } header: {
                    Text("")
                }
                Section {
                    ForEach(
                        viewModel.conversationItems.sorted { $0.latestStartedAt > $1.latestStartedAt },
                        id: \.conversationId
                    ) { item in
                        let conversation = Store.ensureConversation(item.conversationId)
                        HStack {
                            NavigationLink(conversation.title, value: conversation)
                            Spacer()
                            Text("\(item.unreadCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                } header: {
                    HStack {
                        Text("Chats")
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .navigationDestination(for: Conversation.self) { conversation in
                conversationDestination(conversation: conversation)
            }
            .navigationDestination(for: Route.self) { route in
                            switch route {
                                case .new:
                                NewChatView(navigationPath: $navigationPath)
                                case .join:
                                if let conversationId, let batchId {
                                    destinationViewToJoin(for: conversationId, batchId: batchId)
                                }
                            default:
                                Text("Unknown screen")
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
    }
    
    private func conversationDestination(conversation: Conversation) -> AnyView {
        let vm = ConversationViewModel(conversation: conversation)
        if !theme.isAccent, #available(iOS 18.0, *) {
            return AnyView(
                ConversationView(viewModel: vm, path: $navigationPath)
                    .chatTheme(themeColor: color)
            )
        } else {
            return AnyView(
                ConversationView(viewModel: vm, path: $navigationPath)
                    .chatTheme(accentColor: color, images: theme.images)
            )
        }
    }
    
    private func destinationViewToJoin(for convId: String, batchId: String) -> AnyView {
        var conversation = Store.ensureConversation(convId)
        conversation.batchId = batchId
        let vm = ConversationViewModel(conversation: conversation)
        if !theme.isAccent, #available(iOS 18.0, *) {
            return AnyView(
                ConversationView(viewModel: vm, path: $navigationPath)
                    .chatTheme(themeColor: color)
            )
        } else {
            return AnyView(
                ConversationView(viewModel: vm, path: $navigationPath)
                    .chatTheme(accentColor: color, images: theme.images)
            )
        }
    }
    
    private func setup() {
        
        let currentDepth = navigationPath.count
        print("currentDepth=\(currentDepth)")
        
        if isFirstAppear {
            SocketIOManager.shared.disconnect()
            isFirstAppear = false
        }
        
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


