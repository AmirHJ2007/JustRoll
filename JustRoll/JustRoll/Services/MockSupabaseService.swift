import Foundation

final class MockSupabaseService: SupabaseServiceProtocol {

    static let shared = MockSupabaseService()

    var currentUser: User? = User(
        id: "user-me",
        email: "amir@example.com",
        name: "Amir",
        username: "amir"
    )

    // Mutable state so UI actions (leave, end, create) stick within the session
    private var sessions: [Session] = MockSupabaseService.seedSessions()
    private var contacts: [Contact] = MockSupabaseService.seedContacts()
    private var pendingPhotos: [PendingPhoto] = MockSupabaseService.seedPendingPhotos()

    // MARK: Auth

    func signIn(email: String, password: String) async throws -> User {
        return currentUser!
    }

    func signOut() async throws {}

    // MARK: Sessions

    func fetchSessions() async throws -> [Session] {
        try await mockDelay()
        return sessions
    }

    func createSession(name: String) async throws -> Session {
        try await mockDelay(0.4)
        let code = randomCode()
        let session = Session(
            id: UUID().uuidString,
            code: code,
            name: name,
            members: [SessionMember(id: "user-me", name: "Amir", joinedAt: Date())],
            status: .active,
            createdAt: Date()
        )
        sessions.insert(session, at: 0)
        return session
    }

    func joinSession(code: String) async throws -> Session {
        try await mockDelay(0.4)
        guard let session = sessions.first(where: { $0.code == code }) else {
            throw ServiceError.sessionNotFound
        }
        return session
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

    // MARK: Contacts

    func fetchContacts() async throws -> [Contact] {
        try await mockDelay()
        return contacts
    }

    func addContact(username: String) async throws -> Contact {
        try await mockDelay(0.4)
        let contact = Contact(id: UUID().uuidString, name: username, username: username, isConnected: true)
        contacts.append(contact)
        return contact
    }

    func removeContact(contactId: String) async throws {
        try await mockDelay(0.2)
        contacts.removeAll { $0.id == contactId }
    }

    // MARK: Photos

    func fetchPendingPhotos() async throws -> [PendingPhoto] {
        try await mockDelay()
        // TODO: PhotoKit — real implementation reads PHPhotoLibrary filtered by
        // session.createdAt ... session member's leftAt timestamp using PHAsset.creationDate.
        return pendingPhotos
    }

    func uploadPhotos(_ photos: [PendingPhoto], sessionId: String) async throws {
        // TODO: Supabase Storage — upload each photo, then insert rows in photo_deliveries
        // tagged per recipient using Session.recipients(at: captureDate).
        try await mockDelay(1.2)
        pendingPhotos.removeAll { photo in photos.contains(where: { $0.id == photo.id }) }
    }

    // MARK: Seed data

    private static func seedSessions() -> [Session] {
        let now = Date()
        return [
            Session(
                id: "session-1",
                code: "4F9K2",
                name: "Friday night",
                members: [
                    SessionMember(id: "user-me",   name: "Amir",  joinedAt: now.addingTimeInterval(-7200)),
                    SessionMember(id: "user-sara",  name: "Sara",  joinedAt: now.addingTimeInterval(-6800)),
                    SessionMember(id: "user-james", name: "James", joinedAt: now.addingTimeInterval(-5000)),
                ],
                status: .active,
                createdAt: now.addingTimeInterval(-7200)
            ),
            Session(
                id: "session-2",
                code: "BX31R",
                name: "Park hangout",
                members: [
                    SessionMember(id: "user-me",   name: "Amir", joinedAt: now.addingTimeInterval(-172800), leftAt: now.addingTimeInterval(-86400)),
                    SessionMember(id: "user-lena",  name: "Lena", joinedAt: now.addingTimeInterval(-172800), leftAt: now.addingTimeInterval(-86400)),
                    SessionMember(id: "user-james", name: "James",joinedAt: now.addingTimeInterval(-170000), leftAt: now.addingTimeInterval(-90000)),
                ],
                status: .ended,
                createdAt: now.addingTimeInterval(-172800)
            ),
        ]
    }

    private static func seedContacts() -> [Contact] {
        [
            Contact(id: "user-sara",   name: "Sara Chen",      username: "sarachen",   isConnected: true),
            Contact(id: "user-james",  name: "James Park",     username: "jpark",      isConnected: true),
            Contact(id: "user-lena",   name: "Lena Kovacs",    username: "lenakovacs", isConnected: true),
            Contact(id: "user-marcus", name: "Marcus Williams", username: "marcusw",   isConnected: false),
        ]
    }

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

    private func mockDelay(_ seconds: Double = 0.2) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func randomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).compactMap { _ in chars.randomElement() })
    }
}
