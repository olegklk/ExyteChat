import Foundation

struct Contact: Codable, Identifiable, Hashable {
    let id: String
    let username: String?
    let firstname: String
    let lastname: String?
    let picture: String?
}
