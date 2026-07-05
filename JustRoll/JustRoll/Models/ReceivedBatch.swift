import Foundation

struct ReceivedBatch: Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let senderName: String
    var senderAvatarId: Int? = nil
    let rollingStartedAt: Date
    let rollingStoppedAt: Date
    var photos: [ReceivedPhoto]
    var isSaved: Bool = false
}

struct ReceivedPhoto: Identifiable {
    let id: String
    let batchId: String
    let url: String?          // Supabase Storage URL — nil in mock
    let captureDate: Date
    var isSelected: Bool = true
    var thumbnailUrl: URL? = nil
    var fullResUrl: URL? = nil
    var mockColorSeed: Int { id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }
}
