import SwiftUI
import ChatAPIClient
import ExyteChat

struct ConversationListView: View {
    
    @StateObject private var viewModel : ConversationListViewModel = ConversationListViewModel()
    
    @Binding var navigationPath: NavigationPath
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.black)
        
    @State private var conversationId: String?
    
    var body: some View {
        List {
            Section {
                ForEach(
                    viewModel.conversationItems.sorted { $0.latestStartedAt > $1.latestStartedAt },
                    id: \.conversationId
                ) { item in
                    let conversation = Store.ensureConversation(item.conversationId)
                    HStack {
//
                        Button(conversation.title ?? conversation.id) {
                            
                            navigationPath.append(NavigationItem(screenType: AppScreen.chat, conversation:conversation))
                        }
                        .foregroundColor(.primary)
                        
                        Spacer()
                        Text("\(item.unreadCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
            } header: {
                HStack {
                    Text("Chats")
                    if viewModel.isLoading {
                    ExyteChat.ActivityIndicator()
                            .frame(width: 20, height: 20)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigationPath.append(NavigationItem(screenType: AppScreen.newChat, conversation: nil))
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Color(red: 0.34, green: 0.78, blue: 0.78))
                }
            }
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
                        return AnyView(
                            ConversationView(viewModel: vm, path: $navigationPath)
                        )
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


