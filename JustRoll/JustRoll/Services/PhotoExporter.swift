import AVFoundation
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

    /// Full-res video export via AVAssetExportSession, highest-quality preset, MP4 container.
    static func exportVideo(_ asset: PHAsset) async -> Data? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let exportSession: AVAssetExportSession? = await withCheckedContinuation { cont in
            PHImageManager.default().requestExportSession(
                forVideo: asset, options: options,
                exportPreset: AVAssetExportPresetHighestQuality
            ) { session, _ in
                cont.resume(returning: session)
            }
        }
        guard let exportSession else { return nil }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Always clean up the temp file, regardless of how we exit below.
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let success: Bool = await withCheckedContinuation { cont in
            exportSession.exportAsynchronously {
                cont.resume(returning: exportSession.status == .completed)
            }
        }
        guard success else { return nil }

        return try? Data(contentsOf: outputURL)
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
