import Photos
import UIKit

struct PhotoExporter {
    /// Full-res JPEG at 87% quality — matches Google Photos / iCloud default.
    static func exportFullRes(_ asset: PHAsset) async -> Data? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                guard let data, let image = UIImage(data: data) else {
                    cont.resume(returning: nil); return
                }
                cont.resume(returning: image.jpegData(compressionQuality: 0.87))
            }
        }
    }

    /// Thumbnail: max 640px on long edge, JPEG at 72%.
    static func exportThumbnail(_ asset: PHAsset) async -> Data? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous = false
            let size = CGSize(width: 640, height: 640)
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFit, options: opts
            ) { image, _ in
                guard let image else { cont.resume(returning: nil); return }
                cont.resume(returning: image.jpegData(compressionQuality: 0.72))
            }
        }
    }
}
