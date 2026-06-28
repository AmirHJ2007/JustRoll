import Foundation
import Observation

@Observable
@MainActor
final class UnsentViewModel {
    var pendingPhotos: [PendingPhoto] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    // Groups pending photos by session for the Unsent list.
    var groupedBySession: [(sessionName: String, sessionId: String, photos: [PendingPhoto])] {
        let grouped = Dictionary(grouping: pendingPhotos, by: \.sessionId)
        return grouped.map { sessionId, photos in
            (sessionName: photos.first?.sessionName ?? "Roll", sessionId: sessionId, photos: photos)
        }.sorted { $0.sessionName < $1.sessionName }
    }

    func load() async {
        isLoading = true
        // TODO: PhotoKit — when wiring up real photo collection, call collectPhotos(for:) here
        // using the session window timestamps. The review-and-deselect screen is the required
        // privacy gate before any upload occurs.
        do {
            pendingPhotos = try await service.fetchPendingPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendPhotos(_ photos: [PendingPhoto]) async {
        guard let sessionId = photos.first?.sessionId else { return }
        isSending = true
        do {
            // TODO: Supabase — uploadPhotos tags each photo per recipient using
            // Session.recipients(at: photo.captureDate). Late joiners only get photos
            // taken after they joined.
            try await service.uploadPhotos(photos, sessionId: sessionId)
            pendingPhotos.removeAll { p in photos.contains(where: { $0.id == p.id }) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
