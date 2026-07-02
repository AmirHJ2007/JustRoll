import Foundation

struct Contact: Identifiable, Equatable {
    let id: String
    let name: String
    let username: String
    var isConnected: Bool
    var isPending: Bool  = false
    var isIncoming: Bool = false  // true = they sent the request to me
}
