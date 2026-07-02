import Foundation

struct PendingBatch: Identifiable {
    let id: String          // == sessionId
    let sessionName: String
    var photos: [PendingPhoto]
    let rollingStartedAt: Date
    let rollingStoppedAt: Date
    let recipientNames: [String]

    // 7 days to review before auto-expiry (discarded — never silently sent)
    var expiresAt: Date { rollingStoppedAt.addingTimeInterval(7 * 24 * 3600) }
    var timeUntilExpiry: TimeInterval { expiresAt.timeIntervalSinceNow }
    var isUrgent: Bool { timeUntilExpiry < 24 * 3600 }
}
