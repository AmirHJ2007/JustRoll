import Foundation
import Observation

@Observable
@MainActor
final class SessionsViewModel {
    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?
    var showStartSheet = false

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    var activeSessions: [Session] { sessions.filter { $0.status == .active || $0.status == .pending } }
    var endedSessions:  [Session] { sessions.filter { $0.status == .ended } }

    func load() async {
        isLoading = true
        do {
            sessions = try await service.fetchSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createSession(name: String) async throws -> Session {
        let session = try await service.createSession(name: name)
        sessions.insert(session, at: 0)
        return session
    }

    func joinSession(code: String) async throws -> Session {
        let session = try await service.joinSession(code: code)
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0)
        }
        return session
    }

    func leaveSession(_ session: Session) async {
        do {
            try await service.leaveSession(sessionId: session.id)
            syncStatus(sessionId: session.id, to: .ended)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endSession(_ session: Session) async {
        do {
            try await service.endSession(sessionId: session.id)
            syncStatus(sessionId: session.id, to: .ended)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncStatus(sessionId: String, to status: SessionStatus) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = status
    }
}
