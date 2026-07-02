import Foundation
import Observation
import Photos

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

    var currentUserId: String? { service.currentUser?.id }

    var activeSessions: [Session] {
        sessions.filter {
            $0.status == .active || $0.status == .pending ||
            ($0.status == .ended && $0.kind == .lasting)
        }
    }
    var endedSessions: [Session] { sessions.filter { $0.status == .ended && $0.kind == .disposable } }

    func load() async {
        isLoading = true
        do {
            sessions = try await service.fetchSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createSession(name: String, kind: SessionKind, invitedContacts: [Contact] = []) async throws -> Session {
        let session = try await service.createSession(name: name, kind: kind, invitedContacts: invitedContacts)
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

    func deleteSession(_ session: Session) async {
        do {
            try await service.deleteSession(sessionId: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRolling(_ session: Session) async {
        do {
            try await service.startRolling(sessionId: session.id)
            let now = Date()
            syncStatus(sessionId: session.id, to: .active)
            syncMemberRolling(sessionId: session.id, isRolling: true)
            syncRollingWindow(sessionId: session.id, startedAt: now, stoppedAt: nil)
            await requestPhotoLibraryAccessIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRolling(_ session: Session) async {
        do {
            try await service.stopRolling(sessionId: session.id)
            let now = Date()
            syncStatus(sessionId: session.id, to: .pending)
            syncMemberRolling(sessionId: session.id, isRolling: false)
            syncRollingWindow(sessionId: session.id, startedAt: nil, stoppedAt: now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // func fetchContactsForPicker() async throws -> [Contact] { ... }  // contacts feature disabled

    private func requestPhotoLibraryAccessIfNeeded() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    private func syncStatus(sessionId: String, to status: SessionStatus) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].status = status
    }

    private func syncMemberRolling(sessionId: String, isRolling: Bool) {
        guard let sid = sessions.firstIndex(where: { $0.id == sessionId }),
              let uid = currentUserId,
              let mid = sessions[sid].members.firstIndex(where: { $0.id == uid }) else { return }
        sessions[sid].members[mid].isRolling = isRolling
    }

    private func syncRollingWindow(sessionId: String, startedAt: Date?, stoppedAt: Date?) {
        guard let sid = sessions.firstIndex(where: { $0.id == sessionId }),
              let uid = currentUserId,
              let mid = sessions[sid].members.firstIndex(where: { $0.id == uid }) else { return }
        if let start = startedAt { sessions[sid].members[mid].rollingStartedAt = start }
        if let stop = stoppedAt  { sessions[sid].members[mid].rollingStoppedAt = stop }
    }
}
