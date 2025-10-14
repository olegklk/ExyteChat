import SwiftUI

struct VeroContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var items: [Item] = []
    let onSelect: (String) -> Void

    struct Item: Identifiable {
        let id: String
        let name: String
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if items.isEmpty {
                    Text("No contacts").foregroundColor(.secondary)
                } else {
                    List(items) { item in
                        Button {
                            onSelect(item.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(item.name)
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
        let contacts = await service.getContacts(token) ?? []
        self.items = contacts.compactMap { contact in
            guard let id = extractId(contact) else { return nil }
            let name = extractName(contact) ?? "Contact"
            return Item(id: id, name: name)
        }
    }

    // Пытаемся вытащить id из распространённых полей (id/userId/user_id/userID)
    private func extractId<T>(_ contact: T) -> String? {
        let m = Mirror(reflecting: contact)
        for child in m.children {
            guard let label = child.label?.lowercased() else { continue }
            if ["id", "userid", "user_id", "userId".lowercased(), "userID".lowercased()].contains(label) {
                return String(describing: child.value)
            }
        }
        return nil
    }

    // Пытаемся вытащить имя для отображения
    private func extractName<T>(_ contact: T) -> String? {
        let m = Mirror(reflecting: contact)
        for child in m.children {
            guard let label = child.label?.lowercased() else { continue }
            if ["name", "displayname", "display_name", "username", "email", "title"].contains(label) {
                return String(describing: child.value)
            }
        }
        return nil
    }
}
