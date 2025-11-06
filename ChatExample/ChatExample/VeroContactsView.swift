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
/*
 Printing description of contact:
 ▿ Contact
   - id : "e764ce90-d15b-11e4-ae7e-4109879f609b"
   - username : nil
   - firstname : "O"
   ▿ lastname : Optional<String>
     - some : "K"
   - picture : nil
 Printing description of contact:
 ▿ Contact
   - id : "d05f2f50-d2b5-11e4-92c6-e365c4562176"
   - username : nil
   - firstname : "O-test"
   ▿ lastname : Optional<String>
     - some : "K"
   - picture : nil
 Printing description of contact:
 ▿ Contact
   - id : "f24e3310-d2cc-11e4-a8c4-4109879f609b"
   - username : nil
   - firstname : "O2 K"
   - lastname : nil
   - picture : nil
 Printing description of contact:
 ▿ Contact
   - id : "d5c78030-fd50-11e4-8f87-e365c4562176"
   ▿ username : Optional<String>
     - some : "oleg5"
   - firstname : "Oleg5 Klk"
   - lastname : nil
   ▿ picture : Optional<String>
     - some : "https://d12p2d3hz1zns.cloudfront.net/d5c78030-fd50-11e4-8f87-e365c4562176/6c325af9-77ad-465c-8b52-7d493efc3b18"
 Printing description of contact:
 ▿ Contact
   - id : "46f89ea0-1e4a-11e5-916b-693194eb50e3"
   - username : nil
   - firstname : "Oleg-test2"
   ▿ lastname : Optional<String>
     - some : "Klk"
   - picture : nil
 */
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
//            .navigationTitle("Vero Contacts")
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Close") { dismiss() }
//                }
//            }
            .searchable( //в этом экране почему-то сверху оставлено широкое пустое пространство как будто зарезервированное для показан navigationTitle или еще чего-то в этом роде но там ничего нет, как его убрать чтобы search был прижат к верху формы AI!
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
