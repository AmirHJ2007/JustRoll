import Foundation

protocol SupabaseServiceProtocol: AnyObject {
    var currentUser: User? { get }

    // MARK: Auth
    func restoreSession() async -> User?
    func signIn(email: String, password: String) async throws -> User
    func signUp(name: String, username: String, email: String, password: String, avatarId: Int?) async throws -> User
    func signOut() async throws
    /// True if another profile already claimed this username. Callable before auth.
    func isUsernameTaken(_ username: String) async throws -> Bool
    /// Change the signed-in user's preset avatar (1–12), or nil to clear it.
    func updateAvatar(_ avatarId: Int?) async throws
    /// Permanently erases the signed-in user's account and all associated data
    /// (photos, deliveries, contacts, profile), and removes them from every
    /// circle they belong to. Cannot be undone.
    func deleteAccount() async throws

    // MARK: Sessions
    func fetchSessions() async throws -> [Session]
    func createSession(name: String, kind: SessionKind, invitedContacts: [Contact]) async throws -> Session
    func joinSession(code: String) async throws -> Session
    func leaveSession(sessionId: String) async throws
    func endSession(sessionId: String) async throws
    func deleteSession(sessionId: String) async throws
    func startRolling(sessionId: String) async throws
    func stopRolling(sessionId: String) async throws
    /// Add a user to an existing session by their username (creator only).
    func inviteMemberToSession(sessionId: String, username: String) async throws

    // MARK: Contacts (disabled — re-enable with friend graph feature)
    // func fetchContacts() async throws -> [Contact]
    // func addContact(username: String) async throws -> Contact
    // func removeContact(contactId: String) async throws
    // func acceptContact(contactId: String) async throws

    // MARK: Profile & Preferences
    func fetchProfile() async throws -> User
    func updatePreferences(nudges: Bool, newPhotos: Bool) async throws
    func fetchPreferences() async throws -> (nudges: Bool, newPhotos: Bool)

    // MARK: Photos
    func fetchPendingPhotos() async throws -> [PendingPhoto]
    func fetchPendingBatches() async throws -> [PendingBatch]
    func uploadPhotos(_ photos: [PendingPhoto], sessionId: String, rollId: String) async throws
    /// Throw away an unsent roll without sending anything — forgets it locally
    /// AND marks it consumed server-side so it isn't re-discovered on next load.
    func discardBatch(sessionId: String, rollId: String) async throws
    func fetchReceivedBatches() async throws -> [ReceivedBatch]
    func markBatchSaved(batchId: String, savedPhotoIds: [String], dismissedPhotoIds: [String]) async throws
}

enum ServiceError: LocalizedError {
    case sessionNotFound
    case userNotFound
    case unauthorized
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:       return "No roll found with that code."
        case .userNotFound:          return "No user found with that username."
        case .unauthorized:          return "You need to be signed in."
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        }
    }
}
