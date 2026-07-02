import Foundation
import Photos

struct PendingPhoto: Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let captureDate: Date
    var isSelected: Bool
    var isVideo: Bool = false
    var asset: PHAsset? = nil

    // Mock fallback: stable color index for placeholder rendering when asset is nil.
    var mockColorSeed: Int {
        id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    }
}
