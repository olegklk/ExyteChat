import SwiftUI
import ExyteChat

struct ConversationListView: View {
    
    //перепиши этот класс так на onAppear запускался метод viewModel.onAppear и чтобы внути List отображались объекты viewModel.conversationItems (в качестве title - первые 10 символов от их свойства conversationId и справа число unreadCount). Элементы в списке должны быть отсортированы по свойству latestUnreadStartedAt AI!
    
    private var viewModel: ConversationListViewModel = ConversationListViewModel()
    
    @State private var theme: ExampleThemeState = .accent
    @State private var color = Color(.exampleBlue)
    
    var body: some View {
        NavigationView {
            List {
                Section {
//                    NavigationLink("Active chat example") {
//                        if !theme.isAccent, #available(iOS 18.0, *) {
//                            ChatExampleView(
//                                viewModel: ChatExampleViewModel(interactor: MockChatInteractor(isActive: true)),
//                                title: "Active chat example"
//                            )
//                            .chatTheme(themeColor: color)
//                        } else {
//                            ChatExampleView(
//                                viewModel: ChatExampleViewModel(interactor: MockChatInteractor(isActive: true)),
//                                title: "Active chat example"
//                            )
//                            .chatTheme(
//                                accentColor: color,
//                                images: theme.images
//                            )
//                        }
//                    }
//                    
//                    NavigationLink("Simple chat example") {
//                        if !theme.isAccent, #available(iOS 18.0, *) {
//                            ChatExampleView(viewModel: ChatExampleViewModel(), title: "Simple chat example")
//                                .chatTheme(themeColor: color)
//                        } else {
//                            ChatExampleView(viewModel: ChatExampleViewModel(), title: "Simple chat example")
//                                .chatTheme(
//                                    accentColor: color,
//                                    images: theme.images
//                                )
//                        }
//                    }
//
//                    NavigationLink("Simple comments example") {
//                        CommentsExampleView()
//                            .chatTheme(.init(colors: .init(
//                                inputSignatureBG: .white.opacity(0.5),
//                                inputSignatureText: .black,
//                                inputSignaturePlaceholderText: .black.opacity(0.7)
//                            )))
//                            .mediaPickerTheme(
//                                main: .init(
//                                    pickerText: .white,
//                                    pickerBackground: Color(.examplePickerBg),
//                                    fullscreenPhotoBackground: Color(.examplePickerBg)
//                                ),
//                                selection: .init(
//                                    accent: Color(.exampleBlue)
//                                )
//                            )
//                    }

                    NavigationLink("Chat (demo)") {
                        if !theme.isAccent, #available(iOS 18.0, *) {
                            ConversationView(viewModel: ConversationViewModel(), title: "Chat (demo)")
                                .chatTheme(themeColor: color)
                        } else {
                            ConversationView(viewModel: ConversationViewModel(), title: "Chat (demo)")
                                .chatTheme(
                                    accentColor: color,
                                    images: theme.images
                                )
                        }
                        
                    }
                } header: {
                    Text("")
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


