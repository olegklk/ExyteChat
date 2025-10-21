import SwiftUI
import ChatAPIClient
import ExyteChat

struct ConversationListView: View {
    
    @StateObject private var viewModel : ConversationListViewModel = ConversationListViewModel()
    
    @Binding var navigationPath: NavigationPath
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.black)
    
    @State private var conversationURL: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    @State private var conversationId: String?
    @State private var batchId: String?
    
    var body: some View {
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
                Text("Join by URL")
            }

            Section {
                VStack {
                    Button("Create New Chat") {
                        navigationPath.append(NavigationItem(screenType: AppScreen.newChat, conversation: nil))
                    }
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
//
                        Button(conversation.title) {
                            
                            navigationPath.append(NavigationItem(screenType: AppScreen.chat, conversation:conversation))
                        }
                        .foregroundColor(.black)
                        
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
        .navigationDestination(for: NavigationItem.self) { item in
            conversationDestination(item)
        }
        .navigationTitle("Chats ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                HStack {
//                    Button(theme.title) {
//                        theme = theme.next()
//                    }
//                    ColorPicker("", selection: $color)
//                }
//            }
        }
        .onAppear(perform: setup)
        
    }
    
    private func conversationDestination(_ item: NavigationItem) -> AnyView {
        switch item.screenType  {
            case .newChat:
                return AnyView(
                    NewChatView(navigationPath: $navigationPath)
                )
            case .chat:
                if let conversation = item.conversation {
                    let vm = ConversationViewModel(conversation: conversation)
                    if #available(iOS 18.0, *) {
                        return AnyView(
                            ConversationView(viewModel: vm, path: $navigationPath)
                                .chatTheme(themeColor: color, background: .static(color))
                        )
                    } else {
                        return AnyView(
                            ConversationView(viewModel: vm, path: $navigationPath)
                                .chatTheme(accentColor: color, images: theme.images)
                        )
                    }
                }
            case .userSetup, .chatList:
                break
        }
        return AnyView(
            EmptyView()
        )
    }
    
    private func setup() {
                
//        if currentDepth == 0 {
//            SocketIOManager.shared.disconnect()
//        }
        
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


