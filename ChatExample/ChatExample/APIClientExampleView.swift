//
//  APIClientExampleView.swift
//  ChatExample
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient

struct APIClientExampleView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject private var viewModel: APIClientExampleViewModel
    
    private let title: String
    
    init(viewModel: APIClientExampleViewModel, title: String) {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        if let url = viewModel.chatCover {
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
                            Text(viewModel.chatTitle)
                                .fontWeight(.semibold)
                                .font(.headline)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                            Text(viewModel.chatStatus)
                                .font(.footnote)
                                .foregroundColor(Color(hex: "AFB3B8"))
                        }
                        Spacer()
                    }
                    .padding(.leading, 10)
                }
                ToolbarItem(placement: .principal) {
                    let idString = viewModel.conversationId ?? ""
                    Text(idString)
                        .font(.headline)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy") { UIPasteboard.general.string = idString }
                        }
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}



struct APIClientExampleView_Previews: PreviewProvider {
    static var previews: some View {
        APIClientExampleView(viewModel: APIClientExampleViewModel(), title: "Chat (demo)")
    }
}
