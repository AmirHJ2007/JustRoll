import Foundation

protocol SupabaseServiceProtocol: AnyObject {
    var currentUser: User? { get }

    // MARK: Auth
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws

    // MARK: Sessions
    func fetchSessions() async throws -> [Session]
    func createSession(name: String) async throws -> Session
    func joinSession(code: String) async throws -> Session
    func leaveSession(sessionId: String) async throws
    func endSession(sessionId: String) async throws

    // MARK: Contacts
    func fetchContacts() async throws -> [Contact]
    func addContact(username: String) async throws -> Contact
    func removeContact(contactId: String) async throws

    // MARK: Photos
    // TODO: PhotoKit — add collectPhotos(for session: Session) async throws -> [PendingPhoto]
    // This reads PHPhotoLibrary, filters by captureDate within session window,
    // and returns candidates for the review-and-deselect screen.
    func fetchPendingPhotos() async throws -> [PendingPhoto]
    func uploadPhotos(_ photos: [PendingPhoto], sessionId: String) async throws
    // TODO: Delivery — fetchIncomingPhotos() async throws -> [IncomingPhoto]
    // Silent push wakes app; this is called to pull and save to camera roll.
}

enum ServiceError: LocalizedError {
    case sessionNotFound
    case unauthorized
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:       return "No roll found with that code."
        case .unauthorized:          return "You need to be signed in."
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        }
    }
}
