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
                ToolbarItem(placement: .primaryAction) {
                    Text(viewModel.conversation.type ?? "")
                        .font(.subheadline)
                }
            })
            .onAppear {
                let currentDepth = navigationPath.count
                print("currentDepth=\(currentDepth)")
                viewModel.onAppear()
            }
        }
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
