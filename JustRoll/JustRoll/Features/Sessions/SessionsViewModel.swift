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

    var currentUser: User? { service.currentUser }
    var currentUserId: String? { service.currentUser?.id }

    var activeSessions: [Session] {
        let uid = currentUserId
        return sessions
            .filter {
                $0.status == .active || $0.status == .pending ||
                ($0.status == .ended && $0.kind == .lasting)
            }
            .sorted { a, b in
                // 1. User is currently rolling → float to top
                let aRolling = uid.flatMap { u in a.members.first(where: { $0.id == u }) }?.isRolling ?? false
                let bRolling = uid.flatMap { u in b.members.first(where: { $0.id == u }) }?.isRolling ?? false
                if aRolling != bRolling { return aRolling }

                // 2. Most recent activity: creation or last rolling event
                let aMember = uid.flatMap { u in a.members.first(where: { $0.id == u }) }
                let bMember = uid.flatMap { u in b.members.first(where: { $0.id == u }) }
                let aDate = ([a.createdAt, aMember?.rollingStartedAt, aMember?.rollingStoppedAt]
                    .compactMap { $0 }).max() ?? a.createdAt
                let bDate = ([b.createdAt, bMember?.rollingStartedAt, bMember?.rollingStoppedAt]
                    .compactMap { $0 }).max() ?? b.createdAt
                return aDate > bDate
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

    func inviteMembersToSession(sessionId: String, usernames: [String]) async {
        for username in usernames {
            try? await service.inviteMemberToSession(sessionId: sessionId, username: username)
        }
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
            if session.kind == .lasting {
                // Lasting circles are shared — only remove this user, leave it intact for others
                try await service.leaveSession(sessionId: session.id)
            } else {
                try await service.deleteSession(sessionId: session.id)
            }
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

    // MARK: - Empty-roll check

    /// Counts real camera photos and videos in a rolling window using the same
    /// asset filtering logic as `fetchPendingBatches` (same PNG/screenshot exclusion).
    ///
    /// Returns -1 when photo library permission is not granted — callers treat
    /// -1 as "unknown" and should NOT trigger the empty-roll overlay.
    nonisolated static func countAssetsInWindow(from start: Date, to stop: Date) -> Int {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else { return -1 }

        let windowStart = start as NSDate
        let windowEnd   = stop  as NSDate
        let timePredicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            windowStart, windowEnd
        )
        let opts = PHFetchOptions()
        opts.predicate = timePredicate

        // Screenshots are PNG ("public.png" on iOS 14+ / "com.apple.uikit.image" on older).
        // Excluding these keeps parity with fetchPendingBatches so the "empty" verdict
        // matches exactly what would actually show up on the review screen.
        let excludedUTIs: Set<String> = ["public.png", "com.apple.uikit.image"]

        let imageResult = PHAsset.fetchAssets(with: .image, options: opts)
        var count = 0
        for i in 0..<imageResult.count {
            let asset     = imageResult.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)
            let isExcluded = resources.contains { excludedUTIs.contains($0.uniformTypeIdentifier) }
            if !isExcluded { count += 1 }
        }

        let videoResult = PHAsset.fetchAssets(with: .video, options: opts)
        count += videoResult.count
        return count
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
