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
//вынеси из этого кода блок отвечающий за отображение invite url в отдельный скрин который будет доступен из кнопки размещенной в навигационной панели справа и обозначенной символом "..." AI!
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
            // Invite URL block
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Invite URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Copy") {
                        UIPasteboard.general.string = viewModel.conversationURL
                    }
                    .disabled((viewModel.conversationURL ?? "").isEmpty)
                }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    Text(viewModel.conversationURL ?? "")
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(.horizontal, 12)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy") { UIPasteboard.general.string = viewModel.conversationURL }
                        }
                }
                .frame(height: 40)
            }
            .padding([.horizontal, .top])
            ChatView( messages: viewModel.messages,
                      chatType: .conversation,
                      replyMode: .quote) { draft in
                            Task { await viewModel.handleSend(draft) }
                        }
                      messageBuilder: {
                message, positionInGroup, positionInMessagesSection, positionInCommentsGroup,
                showContextMenuClosure, messageActionClosure, showAttachmentClosure in
                messageCell(message, positionInGroup, positionInCommentsGroup, showMenuClosure: showContextMenuClosure, actionClosure: messageActionClosure, attachmentClosure: showAttachmentClosure)
            }
              messageMenuAction: { (action: DefaultMessageMenuAction, defaultActionClosure, message) in
                
                switch action {
                    case .reply:
                        defaultActionClosure(message, .reply)
                    case .edit: defaultActionClosure(message, .edit { editedText in
                        Task {await viewModel.handleEdit(message.id, editedText) }
                        
                    })
                    case .copy: defaultActionClosure(message, .copy)
                }
            }
                      
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
            //        .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
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
                            Text(viewModel.conversation.title)
                                .fontWeight(.semibold)
                                .font(.headline)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        Spacer()
                    }
                    .padding(.leading, 10)
                }
                ToolbarItem(placement: .primaryAction) {
                    Text(viewModel.conversation.type ?? "")
                        .font(.subheadline)
                }
            })
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
    
    fileprivate func messageBubble(_ message: Message, isLastInGroup: Bool) -> some View {
        return Text(message.text)
//            .font(.system(size: 14)).fontWeight(.medium)
            .font(.custom("ProximaNova-Light", size: 18))
            .foregroundStyle(message.user.isCurrentUser ? .white : .black)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight:40)
            .lineSpacing(6)
            .background(
                MessageBubbleShape(
                    isCurrentUser: message.user.isCurrentUser,
                    showTail: isLastInGroup
                )
                .fill(message.user.isCurrentUser
                      ? Color(red: 0, green: 204.0/256.0, blue: 204.0/256.0)
                      : Color(red: 0.95, green: 0.95, blue: 0.95))
            )
    }
    
    @ViewBuilder
    func messageCell(_ message: Message, _ positionInGroup: PositionInUserGroup, _ commentsPosition: CommentsPosition?, showMenuClosure: @escaping ()->(), actionClosure: @escaping (Message, DefaultMessageMenuAction) -> Void, attachmentClosure: @escaping (Attachment) -> Void) -> some View {
        VStack {
            HStack(alignment: .top, spacing: 0) {
                
                if positionInGroup == .last {
                    VStack(alignment: .trailing, spacing: 0) {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 4) {
                            CachedAsyncImage(
                                url: message.user.avatarURL,
                                cacheKey: message.user.avatarCacheKey
                            ) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        }
                        Color.clear
                            .frame(width: 40, height: 20)
                    }
                } else {
                    Color.clear
                        .frame(width: 44, height: 20)
                }
                    

                VStack (alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 0) {

                    if !message.text.isEmpty {
                        VStack {
                            HStack {
                                messageBubble(message, isLastInGroup: positionInGroup == .last)
                                Spacer()
                            }
                        }
                        .padding(.bottom,2.0)
                    }

                    if !message.attachments.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(), count: 2), spacing: 8) {
                            ForEach(message.attachments) { attachment in
                                AttachmentCell(attachment: attachment, size: CGSize(width: 150, height: 150)) { _ in
                                    attachmentClosure(attachment)
                                }
                                .cornerRadius(12)
                                .clipped()
                            }
                        }
                        .frame(width: 308)
                    }
                    if positionInGroup == .last {
                        HStack {
                            Text(message.user.name)
                                .font(.system(size: 12)).fontWeight(.semibold)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(message.createdAt.formatAgo())
                                .font(.system(size: 12)).fontWeight(.medium)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .padding(.leading, message.replyMessage != nil ? 40 : 0)

            if let commentsPosition {
                if commentsPosition.isLastInCommentsGroup {
                    Color.gray.frame(height: 0.5)
                        .padding(.vertical, 10)
                } else if commentsPosition.isLastInChat {
                    Color.clear.frame(height: 5)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .padding(.horizontal, 18)
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
