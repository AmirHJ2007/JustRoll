import Foundation
import Observation

@Observable
@MainActor
final class UnsentViewModel {
    var pendingBatches: [PendingBatch] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    /// True while the review grid is open — RootTabView hides the tab bar so the send bar owns the bottom edge.
    var isReviewing = false
    /// Set by SessionsView (via RootTabView) right after a non-empty stop-rolling, so UnsentView
    /// can jump straight into the review grid for that session's batch.
    var pendingReviewSessionId: String? = nil

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    var totalPhotoCount: Int { pendingBatches.reduce(0) { $0 + $1.photos.count } }
    var unsentCardCount: Int { pendingBatches.count }

    // Legacy — ReviewPhotoGridView takes [PendingPhoto] directly from the batch
    var pendingPhotos: [PendingPhoto] { pendingBatches.flatMap(\.photos) }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            pendingBatches = try await service.fetchPendingBatches()
            // fetchPendingBatches mutates RollStore (discovers rolls from other
            // devices, prunes expired ones) — keep the daily reminder in step.
            NotificationManager.shared.syncUnsentReminder()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func requestReview(forSessionId sessionId: String) async {
        await load()
        pendingReviewSessionId = sessionId
    }

    func sendPhotos(_ photos: [PendingPhoto], from batch: PendingBatch) async {
        errorMessage = nil
        isSending = true
        do {
            try await service.uploadPhotos(photos, sessionId: batch.sessionId, rollId: batch.id)
            let sentIds = Set(photos.map(\.id))
            if let idx = pendingBatches.firstIndex(where: { $0.id == batch.id }) {
                pendingBatches[idx].photos.removeAll { sentIds.contains($0.id) }
                if pendingBatches[idx].photos.isEmpty {
                    pendingBatches.remove(at: idx)
                }
            }
            NotificationManager.shared.syncUnsentReminder()
        } catch {
            errorMessage = error.localizedDescription
            // The card would otherwise stay stuck showing "Uploading" forever.
            UploadManager.shared.cancelBatch(id: batch.id)
        }
        isSending = false
    }

    /// Throw the whole card away without sending anything. Nothing uploads,
    /// nobody receives — the roll is simply forgotten (locally and server-side).
    func discardBatch(_ batch: PendingBatch) async {
        do {
            try await service.discardBatch(sessionId: batch.sessionId, rollId: batch.id)
            pendingBatches.removeAll { $0.id == batch.id }
            NotificationManager.shared.syncUnsentReminder()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
