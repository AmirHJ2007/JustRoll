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

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    var totalPhotoCount: Int { pendingBatches.reduce(0) { $0 + $1.photos.count } }

    // Legacy — ReviewPhotoGridView takes [PendingPhoto] directly from the batch
    var pendingPhotos: [PendingPhoto] { pendingBatches.flatMap(\.photos) }

    func load() async {
        isLoading = true
        do {
            pendingBatches = try await service.fetchPendingBatches()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendPhotos(_ photos: [PendingPhoto]) async {
        guard let sessionId = photos.first?.sessionId else { return }
        isSending = true
        do {
            try await service.uploadPhotos(photos, sessionId: sessionId)
            let sentIds = Set(photos.map(\.id))
            if let idx = pendingBatches.firstIndex(where: { $0.id == sessionId }) {
                pendingBatches[idx].photos.removeAll { sentIds.contains($0.id) }
                if pendingBatches[idx].photos.isEmpty {
                    pendingBatches.remove(at: idx)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
