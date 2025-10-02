import SwiftUI
import ExyteChat

struct ConversationListView: View {
    
    @StateObject private var viewModel : ConversationListViewModel = ConversationListViewModel()
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.exampleBlue)
    
    var body: some View {
        NavigationView {
            List {
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
                }
            }
            .navigationTitle("Chats ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
//                        NavigationLink(destination: NewChatView()) {
//                            Image(systemName: "plus")
//                        }
                        Button(theme.title) {
                            theme = theme.next()
                        }
                        ColorPicker("", selection: $color)
                    }
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
        .navigationViewStyle(.stack)
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


