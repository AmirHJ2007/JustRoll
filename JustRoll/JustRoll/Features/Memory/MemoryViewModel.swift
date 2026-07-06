import Foundation
import Observation

@Observable
@MainActor
final class MemoryViewModel {
    var batches: [ReceivedBatch] = []
    var isLoading = false
    var errorMessage: String?

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    var unsavedCount: Int { batches.filter { !$0.isSaved }.count }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            batches = try await service.fetchReceivedBatches()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markSaved(batch: ReceivedBatch, savedPhotoIds: [String], dismissedPhotoIds: [String]) async {
        do {
            try await service.markBatchSaved(
                batchId: batch.id,
                savedPhotoIds: savedPhotoIds,
                dismissedPhotoIds: dismissedPhotoIds
            )
            if let idx = batches.firstIndex(where: { $0.id == batch.id }) {
                batches[idx].isSaved = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
