import SwiftUI
import ExyteChat

struct VeroContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var contacts: [Contact] = []
    @State private var searchText: String = ""
    let onSelect: (String) -> Void

    private var filteredContacts: [Contact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return contacts }
        return contacts.filter { c in
            let name = "\(c.firstname) \(c.lastname ?? "")".lowercased()
            let uname = (c.username ?? "").lowercased()
            return name.contains(q) || uname.contains(q)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ExyteChat.ActivityIndicator()
                        .frame(width: 20, height: 20)                        
                } else if contacts.isEmpty {
                    Text("No contacts").foregroundColor(.secondary)
                } else {
                    List(filteredContacts) { contact in
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
                    .refreshable {
                        await reloadContacts()
                    }
                }
            }
            .navigationTitle("Vero Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search contacts"
            )
        }
        .task { await loadContacts() }
    }

    private func loadContacts() async {
        let cached = Store.getContacts()
        if !cached.isEmpty {
            await MainActor.run {
                self.contacts = cached
                self.isLoading = false
            }
            return
        }
        await reloadContacts()
    }

    private func reloadContacts() async {
        defer { isLoading = false }
        let service = VeroAuthenticationService.shared
        guard let token = KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt else {
            return
        }
        if service.needRefreshToken(token: token) {
            _ = try? await service.refresh()
        }
        let contacts = await service.getContacts(token) ?? []
        
        await MainActor.run {
            self.contacts = contacts
            Store.setContacts(contacts)
        }
    }

}
