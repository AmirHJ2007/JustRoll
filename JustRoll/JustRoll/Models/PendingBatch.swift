import Foundation

struct PendingBatch: Identifiable {
    let id: String          // roll id (sessionId_startTimestamp) — unique per roll
    let sessionId: String    // the circle's session id — several batches can share this
    let sessionName: String
    var photos: [PendingPhoto]
    let rollingStartedAt: Date
    let rollingStoppedAt: Date
    let recipientNames: [String]
    /// Index-aligned with `recipientNames`. `nil` entries fall back to letter initials.
    let recipientAvatarIds: [Int?]

    // 7 days to review before auto-expiry (discarded — never silently sent)
    var expiresAt: Date { rollingStoppedAt.addingTimeInterval(7 * 24 * 3600) }
    var timeUntilExpiry: TimeInterval { expiresAt.timeIntervalSinceNow }
    var isUrgent: Bool { timeUntilExpiry < 24 * 3600 }
}
