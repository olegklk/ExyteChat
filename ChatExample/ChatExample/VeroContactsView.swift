import SwiftUI

struct VeroContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var contacts: [VeroContact] = []
    let onSelect: (String) -> Void

    final class VeroContact: Identifiable {
        let id: String
        let firstname: String
        let lastname: String?
        let username: String?
        let picture: String?
        init(id: String, firstname: String, lastname: String?, username: String?, picture: String?) {
            self.id = id
            self.firstname = firstname
            self.lastname = lastname
            self.username = username
            self.picture = picture
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if contacts.isEmpty {
                    Text("No contacts").foregroundColor(.secondary)
                } else {
                    List(contacts) { contact in
                        Button {
                            onSelect(contact.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(contact.firstname) \(contact.lastname ?? "")".trimmingCharacters(in: .whitespaces))
                                        .lineLimit(1)
                                    if let username = contact.username, !username.isEmpty {
                                        Text("@\(username)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vero Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadContacts() }
    }

    private func loadContacts() async {
        defer { isLoading = false }
        let service = VeroAuthenticationService.shared
        guard let token = KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt else {
            return
        }
        if service.needRefreshToken(token: token) {
            _ = try? await service.refresh()
        }
        let raw = await service.getContacts(token) ?? []
        self.contacts = raw.compactMap { c in
            let first = c.firstname ?? c.username ?? "Contact"
            return VeroContact(
                id: c.id,
                firstname: first,
                lastname: c.lastname,
                username: c.username,
                picture: c.picture
            )
        }
    }

}
