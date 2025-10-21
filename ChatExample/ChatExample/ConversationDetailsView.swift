import SwiftUI
import UIKit

struct ConversationDetailsView: View {
    let conversationURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Invite URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Copy") {
                    UIPasteboard.general.string = conversationURL
                }
                .disabled((conversationURL ?? "").isEmpty)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                Text(conversationURL ?? "")
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.horizontal, 12)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") { UIPasteboard.general.string = conversationURL }
                    }
            }
            .frame(height: 40)

            Spacer()
        }
        .padding()
        .navigationTitle("Invite URL")
        .navigationBarTitleDisplayMode(.inline)
    }
}
