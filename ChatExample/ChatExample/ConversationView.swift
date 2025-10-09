//
//  ConversationView.swift
//  ChatExample
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import Combine
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient

struct ConversationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject private var viewModel: ConversationViewModel
    
    private let title: String
    
    init(viewModel: ConversationViewModel, title: String) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.title = title
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
                      messageMenuAction: {
                (action: DefaultMessageMenuAction, defaultActionClosure, message) in switch action {
                    case .reply:
                        defaultActionClosure(message, .reply)
                    case .edit: defaultActionClosure(message, .edit { editedText in
                        Task {await viewModel.handleEdit(message.id, editedText) }
                        
                    })
                    case .copy: defaultActionClosure(message, .copy)
                }
            } )
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
                ToolbarItem(placement: .principal) { //переделай этот экран так чтобы conversationURL отображался ниже тулбара - над чатом в отдельном текстовом поле высотой 40px у которого будет подзаголовок "Invite URL" и рядом кнопка "Copy" но при этом сохрани возможность копирования по длинному нажатию как сейчас AI!
                    Text(viewModel.conversationURL ?? "")
                        
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy") { UIPasteboard.general.string = viewModel.conversationURL }
                        }
                }
            })
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}



struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        let conversationid = ChatUtils.generateRandomConversationId()
        let conversation = Store.ensureConversation(conversationid)
        ConversationView(viewModel: ConversationViewModel(conversation: conversation), title: "Chat (demo)")
    }
}
