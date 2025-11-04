//
//  ConversationView.swift
//  ChatExample
//
//  Created by [Your Name] on [Date].
//
//https://chat.gramatune.com/#conversation=c:d5c78030-fd50-11e4-8f87-e365c4562176:f5a53f40-d69b-11e4-b69a-e365c4562176&batch=bcdc8d52-66e6-46a9-8cf1-5a97d880be3d

import SwiftUI
import Combine
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient
private enum ConversationRoute: Hashable { case inviteURL }
struct ConversationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    
    @Binding var navigationPath: NavigationPath
    
    @StateObject private var viewModel: ConversationViewModel
    
    init(viewModel: ConversationViewModel, path: Binding<NavigationPath>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self._navigationPath = path
    }
    
    var body: some View {
        VStack {
            ChatView( messages: viewModel.messages,
                      chatType: .conversation,
                      replyMode: .quote,
                      didSendMessage: { draft in
                            Task { await viewModel.handleSend(draft) }
                        },
                      reactionDelegate: nil,
//                      messageBuilder: {
//                message, positionInGroup, positionInMessagesSection, positionInCommentsGroup,
//                showContextMenuClosure, messageActionClosure, showAttachmentClosure in
//                          messageCell(message, positionInGroup, positionInCommentsGroup, showMenuClosure: showContextMenuClosure, actionClosure: messageActionClosure, attachmentClosure: showAttachmentClosure)
//            },
              messageMenuAction: { (action: DefaultMessageMenuAction, defaultActionClosure, message) in
                
                switch action {
                    case .reply:
                        defaultActionClosure(message, .reply)
                    case .edit: defaultActionClosure(message, .edit { editedText in
                        Task {await viewModel.handleEdit(message.id, editedText) }
                        
                    })
                    case .copy: defaultActionClosure(message, .copy)
                }
            })
                      
            .swipeActions(edge: .leading, performsFirstActionWithFullSwipe: true,
                          items: [
                            SwipeAction(action: onReply, activeFor: { _ in true/*!$0.user.isCurrentUser*/}, background: .blue) {
                    VStack {
                        Image(systemName: "arrowshape.turn.up.left")
                            .imageScale(.large)
                            .foregroundStyle(.white)
                            .frame(height: 30)
                        Text("Reply")
                            .foregroundStyle(.white)
                            .font(.footnote)
                    }
                }
                ])
                   
            .keyboardDismissMode(.interactive)
            .avatarSize(avatarSize: 40)
            //        .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            navigationPath.append(ConversationRoute.inviteURL)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        HStack {
                            if let url = viewModel.conversation.coverURL {
                                CachedAsyncImage(url: url) { phase in
                                    switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Rectangle().fill(Color(hex: "AFB3B8"))
                                    }
                                }
                                .frame(width: 35, height: 35)
                                .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(viewModel.conversation.title ?? viewModel.conversation.id)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.leading, 10)
                    }
                }
            .navigationDestination(for: ConversationRoute.self) { route in
                switch route {
                case .inviteURL:
                    ConversationDetailsView(conversationURL: viewModel.conversationURL)
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onChange(of: navigationPath) { oldPath, newPath in
                if newPath.count < oldPath.count {
                    //just before back navigation - close socket to close batch
                    SocketIOManager.shared.disconnect()
                }
            }
            .background(Color.black)
        }
        
    }
    
    // Swipe Action
    func onReply(message: Message, defaultActions: @escaping (Message, DefaultMessageMenuAction) -> Void) {
        // This places the message in the ChatView's InputView ready for the sender to reply
        defaultActions(message, .reply)
        
    }
    
}



struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        struct PreviewWrapper: View {
            @State private var previewPath = NavigationPath()
            
            var body: some View {
                let conversationid = ChatUtils.generateRandomConversationId()
                let conversation = Store.ensureConversation(conversationid)
                ConversationView(
                    viewModel: ConversationViewModel(conversation: conversation),
                    path: $previewPath
                )
            }
        }
        return PreviewWrapper()
    }
}
