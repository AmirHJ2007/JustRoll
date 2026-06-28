import Foundation

struct PendingPhoto: Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let captureDate: Date
    var isSelected: Bool

    // TODO: PhotoKit — add `var asset: PHAsset` here when wiring up real photo collection.
    // The capture date comes from PHAsset.creationDate (EXIF capture time, not library-added time).
    // Mock stand-in: a stable color index derived from id for thumbnail placeholder rendering.
    var mockColorSeed: Int {
        id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    }
}
