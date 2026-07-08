import Foundation

final class MockSupabaseService: SupabaseServiceProtocol {

    static let shared = MockSupabaseService()

    var currentUser: User? = nil

    private static let seedUser = User(
        id: "user-me",
        email: "amir@example.com",
        name: "Amir",
        username: "amir"
    )

    // Mutable state so UI actions (leave, end, create) stick within the session
    private var sessions: [Session] = MockSupabaseService.seedSessions()
    // private var contacts: [Contact] = MockSupabaseService.seedContacts()  // contacts feature disabled
    private var pendingPhotos: [PendingPhoto] = MockSupabaseService.seedPendingPhotos()
    private var batches: [PendingBatch] = MockSupabaseService.seedPendingBatches()
    private var dynamicBatches: [PendingBatch] = []  // created when rolling stops
    private var receivedBatches: [ReceivedBatch] = MockSupabaseService.seedReceivedBatches()

    // MARK: Auth

    func restoreSession() async -> User? { nil }

    func signIn(email: String, password: String) async throws -> User {
        try await mockDelay(0.6)
        let user = MockSupabaseService.seedUser
        currentUser = user
        return user
    }

    func signUp(name: String, username: String, email: String, password: String, avatarId: Int?) async throws -> User {
        try await mockDelay(0.8)
        let user = User(id: UUID().uuidString, email: email, name: name, username: username, avatarId: avatarId)
        currentUser = user
        return user
    }

    func signOut() async throws {
        currentUser = nil
    }

    func isUsernameTaken(_ username: String) async throws -> Bool {
        try await mockDelay()
        return false
    }

    func updateAvatar(_ avatarId: Int?) async throws {
        try await mockDelay()
        if var user = currentUser {
            user.avatarId = avatarId
            currentUser = user
        }
    }

    func deleteAccount() async throws {
        try await mockDelay(0.8)
        // Reasonable mock of the server-side RPC: leave every seeded circle
        // (remove this user's member row from each session, same as the real
        // delete_account() function does via session_members), then clear all
        // other seeded state and sign out.
        let uid = currentUser?.id ?? "user-me"
        for idx in sessions.indices {
            sessions[idx].members.removeAll { $0.id == uid }
        }
        sessions.removeAll { $0.members.isEmpty }

        pendingPhotos.removeAll()
        batches.removeAll()
        dynamicBatches.removeAll()
        receivedBatches.removeAll()

        currentUser = nil
    }

    // MARK: Sessions

    func fetchSessions() async throws -> [Session] {
        try await mockDelay()
        return sessions
    }

    func createSession(name: String, kind: SessionKind, invitedContacts: [Contact] = []) async throws -> Session {
        try await mockDelay(0.4)
        let code = randomCode()
        let now = Date()
        var members = [SessionMember(id: "user-me", name: "Amir", joinedAt: now)]
        members += invitedContacts.map { SessionMember(id: $0.id, name: $0.name, joinedAt: now) }
        let session = Session(
            id: UUID().uuidString,
            code: code,
            name: name,
            members: members,
            status: .pending,
            createdAt: now,
            kind: kind,
            creatorId: "user-me"
        )
        sessions.insert(session, at: 0)
        return session
    }

    func joinSession(code: String) async throws -> Session {
        try await mockDelay(0.4)
        guard let idx = sessions.firstIndex(where: { $0.code == code }) else {
            throw ServiceError.sessionNotFound
        }

        let uid = currentUser?.id ?? "user-me"
        if !sessions[idx].members.contains(where: { $0.id == uid }) {
            let name = currentUser?.name ?? "Amir"
            sessions[idx].members.append(SessionMember(
                id: uid, name: name, avatarId: currentUser?.avatarId, joinedAt: Date()
            ))
        }
        // Joining puts the user in the circle but doesn't start rolling automatically
        sessions[idx].status = .pending
        return sessions[idx]
    }

    func leaveSession(sessionId: String) async throws {
        try await mockDelay(0.3)
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = .ended
        if let memberIdx = sessions[idx].members.firstIndex(where: { $0.id == "user-me" }) {
            sessions[idx].members[memberIdx].leftAt = Date()
        }
    }

    func endSession(sessionId: String) async throws {
        try await mockDelay(0.3)
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = .ended
        for i in sessions[idx].members.indices where sessions[idx].members[i].leftAt == nil {
            sessions[idx].members[i].leftAt = Date()
        }
    }

    func deleteSession(sessionId: String) async throws {
        try await mockDelay(0.2)
        sessions.removeAll { $0.id == sessionId }
    }

    func inviteMemberToSession(sessionId: String, username: String) async throws {
        try await mockDelay(0.2)
        // In mock: no-op — member list is managed by the UI layer only
    }

    func startRolling(sessionId: String) async throws {
        try await mockDelay(0.2)
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = .active
        if let mIdx = sessions[idx].members.firstIndex(where: { $0.id == currentUser?.id }) {
            sessions[idx].members[mIdx].isRolling = true
            sessions[idx].members[mIdx].rollingStartedAt = Date()
            sessions[idx].members[mIdx].rollingStoppedAt = nil
        }
    }

    func stopRolling(sessionId: String) async throws {
        try await mockDelay(0.2)
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = .pending
        let now = Date()
        if let mIdx = sessions[idx].members.firstIndex(where: { $0.id == currentUser?.id }) {
            sessions[idx].members[mIdx].isRolling = false
            sessions[idx].members[mIdx].rollingStoppedAt = now
            // Build a mock pending batch for this rolling window — id is unique per roll
            // (matches CompletedRoll's id format) so stopping twice yields two cards.
            let start = sessions[idx].members[mIdx].rollingStartedAt ?? now.addingTimeInterval(-300)
            let rollId = "\(sessionId)_\(Int(start.timeIntervalSince1970))"
            let session = sessions[idx]
            let otherMembers = session.members.filter { $0.id != currentUser?.id }
            let recipientNames = otherMembers
                .map { String($0.name.split(separator: " ").first ?? Substring($0.name)) }
            let recipientAvatarIds = otherMembers.map(\.avatarId)
            let mockPhotos = (0..<3).map { i in
                PendingPhoto(
                    id: "mock-\(rollId)-\(i)",
                    sessionId: sessionId,
                    sessionName: session.displayName,
                    captureDate: start.addingTimeInterval(Double(i + 1) * 60),
                    isSelected: true,
                    asset: nil
                )
            }
            let batch = PendingBatch(
                id: rollId,
                sessionId: sessionId,
                sessionName: session.displayName,
                photos: mockPhotos,
                rollingStartedAt: start,
                rollingStoppedAt: now,
                recipientNames: recipientNames,
                recipientAvatarIds: recipientAvatarIds
            )
            dynamicBatches.removeAll { $0.id == rollId }
            dynamicBatches.append(batch)
        }
    }

    // MARK: Contacts (disabled — re-enable with friend graph feature)

    /*
    func fetchContacts() async throws -> [Contact] {
        try await mockDelay()
        return contacts
    }

    func addContact(username: String) async throws -> Contact {
        try await mockDelay(0.4)
        let contact = Contact(id: UUID().uuidString, name: username, username: username,
                              isConnected: false, isPending: true, isIncoming: false)
        contacts.append(contact)
        return contact
    }

    func removeContact(contactId: String) async throws {
        try await mockDelay(0.2)
        contacts.removeAll { $0.id == contactId }
    }

    func acceptContact(contactId: String) async throws {
        try await mockDelay(0.2)
        guard let idx = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        contacts[idx].isConnected = true
        contacts[idx].isPending   = false
        contacts[idx].isIncoming  = false
    }
    */

    func fetchProfile() async throws -> User {
        try await mockDelay(0.2)
        guard let user = currentUser else { throw ServiceError.unauthorized }
        return user
    }

    func fetchPreferences() async throws -> (nudges: Bool, newPhotos: Bool) {
        try await mockDelay(0.1)
        return (nudges: true, newPhotos: true)
    }

    func updatePreferences(nudges: Bool, newPhotos: Bool) async throws {
        try await mockDelay(0.2)
        // No-op in mock; real service persists to user_preferences table
    }

    // MARK: Photos

    func fetchPendingPhotos() async throws -> [PendingPhoto] {
        try await mockDelay()
        // TODO: PhotoKit — real implementation reads PHPhotoLibrary filtered by
        // session.createdAt ... session member's leftAt timestamp using PHAsset.creationDate.
        return pendingPhotos
    }

    func fetchPendingBatches() async throws -> [PendingBatch] {
        try await mockDelay()
        // Merge seed batches with any dynamically created ones (from stopRolling)
        var all = batches
        for dynamic in dynamicBatches {
            if !all.contains(where: { $0.id == dynamic.id }) {
                all.append(dynamic)
            }
        }
        return all
    }

    func uploadPhotos(_ photos: [PendingPhoto], sessionId: String, rollId: String) async throws {
        try await mockDelay(1.2)
        pendingPhotos.removeAll { photo in photos.contains(where: { $0.id == photo.id }) }
        let sentIds = Set(photos.map(\.id))
        // Remove from seed batches
        if let idx = batches.firstIndex(where: { $0.id == rollId }) {
            batches[idx].photos.removeAll { sentIds.contains($0.id) }
            if batches[idx].photos.isEmpty { batches.remove(at: idx) }
        }
        // Remove from dynamic batches
        if let idx = dynamicBatches.firstIndex(where: { $0.id == rollId }) {
            dynamicBatches[idx].photos.removeAll { sentIds.contains($0.id) }
            if dynamicBatches[idx].photos.isEmpty { dynamicBatches.remove(at: idx) }
        }
    }

    func discardBatch(sessionId: String, rollId: String) async throws {
        try await mockDelay(0.3)
        batches.removeAll { $0.id == rollId }
        dynamicBatches.removeAll { $0.id == rollId }
        RollStore.remove(id: rollId)
    }

    func fetchReceivedBatches() async throws -> [ReceivedBatch] {
        try await mockDelay()
        return receivedBatches
    }

    func markBatchSaved(batchId: String, savedPhotoIds: [String], dismissedPhotoIds: [String]) async throws {
        try await mockDelay(0.3)
        if let idx = receivedBatches.firstIndex(where: { $0.id == batchId }) {
            receivedBatches[idx].isSaved = true
        }
    }

    // MARK: Seed data

    private static func seedSessions() -> [Session] {
        let now = Date()
        return [
            Session(
                id: "session-1", code: "4F9K2", name: "Friday night",
                members: [
                    SessionMember(id: "user-me",    name: "Amir",  avatarId: 5, joinedAt: now.addingTimeInterval(-7200), isRolling: true),
                    SessionMember(id: "user-sara",  name: "Sara",  avatarId: 3, joinedAt: now.addingTimeInterval(-6800), isRolling: true),
                    SessionMember(id: "user-james", name: "James", joinedAt: now.addingTimeInterval(-5000), isRolling: false),
                ],
                status: .active, createdAt: now.addingTimeInterval(-7200), kind: .disposable, creatorId: "user-me"
            ),
            Session(
                id: "session-3", code: "XR7QP", name: "Pre-game drinks",
                members: [
                    SessionMember(id: "user-me",     name: "Amir",   avatarId: 5, joinedAt: now.addingTimeInterval(-600), isRolling: false),
                    SessionMember(id: "user-lena",   name: "Lena",   avatarId: 7, joinedAt: now.addingTimeInterval(-450), isRolling: false),
                    SessionMember(id: "user-marcus", name: "Marcus", joinedAt: now.addingTimeInterval(-300), isRolling: false),
                ],
                status: .pending, createdAt: now.addingTimeInterval(-600), kind: .lasting, creatorId: "user-lena"
            ),
            Session(
                id: "session-2", code: "BX31R", name: "Park hangout",
                members: [
                    SessionMember(id: "user-me",    name: "Amir",  avatarId: 5, joinedAt: now.addingTimeInterval(-172800), leftAt: now.addingTimeInterval(-86400)),
                    SessionMember(id: "user-lena",  name: "Lena",  avatarId: 7, joinedAt: now.addingTimeInterval(-172800), leftAt: now.addingTimeInterval(-86400)),
                    SessionMember(id: "user-james", name: "James", joinedAt: now.addingTimeInterval(-170000), leftAt: now.addingTimeInterval(-90000)),
                ],
                status: .ended, createdAt: now.addingTimeInterval(-172800), kind: .disposable, creatorId: "user-me"
            ),
        ]
    }

    // private static func seedContacts() -> [Contact] { ... }  // contacts feature disabled

    private static func seedPendingPhotos() -> [PendingPhoto] {
        let now = Date()
        return (0..<8).map { i in
            PendingPhoto(
                id: "photo-\(i)",
                sessionId: "session-2",
                sessionName: "Park hangout",
                captureDate: now.addingTimeInterval(Double(-(i + 1) * 1200)),
                isSelected: true
            )
        }
    }

    private static func seedPendingBatches() -> [PendingBatch] {
        let now = Date()

        // Batch 1: Park hangout — ended 1 day ago, 6 days left (normal)
        let end1 = now.addingTimeInterval(-24 * 3600)
        let start1 = end1.addingTimeInterval(-3.5 * 3600)
        let photos1 = (0..<8).map { i in
            PendingPhoto(
                id: "photo-\(i)", sessionId: "session-2",
                sessionName: "Park hangout",
                captureDate: start1.addingTimeInterval(Double(i) * 1200),
                isSelected: true
            )
        }

        // Batch 2: Friday night — ended 6.6 days ago, ~9h left (URGENT)
        let end2 = now.addingTimeInterval(-6.625 * 24 * 3600)
        let start2 = end2.addingTimeInterval(-2 * 3600)
        let photos2 = (0..<3).map { i in
            PendingPhoto(
                id: "photo-b2-\(i)", sessionId: "session-1",
                sessionName: "Friday night",
                captureDate: start2.addingTimeInterval(Double(i) * 900),
                isSelected: true
            )
        }

        return [
            PendingBatch(
                id: "session-2_\(Int(start1.timeIntervalSince1970))", sessionId: "session-2", sessionName: "Park hangout",
                photos: photos1, rollingStartedAt: start1, rollingStoppedAt: end1,
                recipientNames: ["Lena", "James", "Sara", "Marcus"],
                recipientAvatarIds: [7, nil, 3, nil]
            ),
            PendingBatch(
                id: "session-1_\(Int(start2.timeIntervalSince1970))", sessionId: "session-1", sessionName: "Friday night",
                photos: photos2, rollingStartedAt: start2, rollingStoppedAt: end2,
                recipientNames: ["Sara", "James"],
                recipientAvatarIds: [3, nil]
            ),
        ]
    }

    private static func seedReceivedBatches() -> [ReceivedBatch] {
        let now = Date()

        let batch1Photos = (0..<7).map { i in
            ReceivedPhoto(id: "recv-b1-\(i)", batchId: "recv-batch-1",
                          url: nil, captureDate: now.addingTimeInterval(-86400 + Double(i * 120)),
                          isVideo: i == 2)
        }
        let batch2Photos = (0..<4).map { i in
            ReceivedPhoto(id: "recv-b2-\(i)", batchId: "recv-batch-2",
                          url: nil, captureDate: now.addingTimeInterval(-172800 + Double(i * 300)))
        }
        let batch3Photos = (0..<12).map { i in
            ReceivedPhoto(id: "recv-b3-\(i)", batchId: "recv-batch-3",
                          url: nil, captureDate: now.addingTimeInterval(-259200 + Double(i * 90)))
        }
        return [
            ReceivedBatch(id: "recv-batch-1", sessionId: "session-1", sessionName: "Friday night",
                          senderName: "Sara", senderAvatarId: 3,
                          rollingStartedAt: now.addingTimeInterval(-86400 - 3600),
                          rollingStoppedAt: now.addingTimeInterval(-86400),
                          photos: batch1Photos, isSaved: false),
            ReceivedBatch(id: "recv-batch-2", sessionId: "session-3", sessionName: "Pre-game drinks",
                          senderName: "Marcus", senderAvatarId: nil,
                          rollingStartedAt: now.addingTimeInterval(-172800 - 2700),
                          rollingStoppedAt: now.addingTimeInterval(-172800),
                          photos: batch2Photos, isSaved: true),
            ReceivedBatch(id: "recv-batch-3", sessionId: "session-4", sessionName: "Rooftop",
                          senderName: "Lena", senderAvatarId: 7,
                          rollingStartedAt: now.addingTimeInterval(-259200 - 5400),
                          rollingStoppedAt: now.addingTimeInterval(-259200),
                          photos: batch3Photos, isSaved: false),
        ]
    }

    private func mockDelay(_ seconds: Double = 0.2) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func randomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).compactMap { _ in chars.randomElement() })
    }
}
