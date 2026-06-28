import Foundation

struct Contact: Identifiable, Equatable {
    let id: String
    let name: String
    let username: String
    var isConnected: Bool
}
