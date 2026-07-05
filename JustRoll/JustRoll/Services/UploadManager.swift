import Foundation
import Observation

/// Tracks per-batch upload progress so the Unsent tab can show a live progress bar.
/// Progress is updated from SupabaseService.uploadPhotos() via MainActor.run.
@Observable
@MainActor
final class UploadManager {
    static let shared = UploadManager()

    /// batchId (sessionId) → fraction complete 0.0–1.0
    var progress: [String: Double] = [:]
    /// batchId → true once all photos have been uploaded and batch_sent is set
    var completed: [String: Bool] = [:]

    func startBatch(id: String, total: Int) {
        progress[id] = total == 0 ? 1.0 : 0.0
        completed[id] = false
    }

    func advancePhoto(batchId: String, index: Int, total: Int) {
        guard total > 0 else { return }
        progress[batchId] = Double(index + 1) / Double(total)
    }

    func finishBatch(id: String) {
        progress[id] = 1.0
        completed[id] = true
        // Remove after a short delay so the UI can animate the completion
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            progress.removeValue(forKey: id)
            completed.removeValue(forKey: id)
        }
    }

    func cancelBatch(id: String) {
        progress.removeValue(forKey: id)
        completed.removeValue(forKey: id)
    }
}
