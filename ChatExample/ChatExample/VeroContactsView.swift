import SwiftUI

struct VeroContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var contacts: [VeroContact] = []
    @State private var searchText: String = ""
    let onSelect: (String) -> Void

    private var filteredContacts: [VeroContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return contacts }
        return contacts.filter { c in
            let name = "\(c.firstname) \(c.lastname ?? "")".lowercased()
            let uname = (c.username ?? "").lowercased()
            return name.contains(q) || uname.contains(q)
        }
    }
//пусть однажды загрузившись контакты сохранялись в памяти в Store.setVeroContacts и далее при открытии этого экрана отображаются уже загруженные контакты (Store.getVeroContacts) при наличии, и только запрашивались с сервера если их еще нет или если  пользователь сделает sorce refresh жестом AI!
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
