import SwiftUI
import Photos

struct ReviewPhotoGridView: View {
    @State private var photos: [PendingPhoto]
    var isSending: Bool
    let onSend: ([PendingPhoto]) -> Void

    init(photos: [PendingPhoto], isSending: Bool = false, onSend: @escaping ([PendingPhoto]) -> Void) {
        self._photos = State(initialValue: photos)
        self.isSending = isSending
        self.onSend = onSend
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var selectedPhotos: [PendingPhoto] { photos.filter(\.isSelected) }
    private var selectedCount: Int { selectedPhotos.count }

    private let mockPalette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    var body: some View {
        VStack(spacing: 0) {
            privacyBanner
            photoGrid
            sendBar
        }
        .navigationTitle("Review photos")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Privacy banner

    private var privacyBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.accentPressed)
            Text("Tap any photo to remove it before sending.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accentPressed)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.accentTint)
    }

    // MARK: - Photo grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos.indices, id: \.self) { i in
                    photoCell(index: i)
                }
            }
        }
    }

    private func photoCell(index: Int) -> some View {
        let photo = photos[index]
        let color = mockPalette[photo.mockColorSeed % mockPalette.count]

        return ZStack(alignment: .topTrailing) {
            PhotoThumbnailCell(photo: photo, fallbackColor: color)
                .aspectRatio(1, contentMode: .fit)

            if !photo.isSelected {
                Color.black.opacity(0.45)
            }

            Image(systemName: photo.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(photo.isSelected ? Theme.Colors.accent : .white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .padding(6)
        }
        .onTapGesture {
            photos[index].isSelected.toggle()
        }
        .animation(.easeInOut(duration: 0.15), value: photo.isSelected)
    }

    // MARK: - Send bar

    private var sendBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if selectedCount == 0 {
                Text("Select at least one photo to send")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            RollButton(
                title: sendTitle,
                isLoading: isSending
            ) {
                onSend(selectedPhotos)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.4 : 1)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.background)
        .overlay(Divider(), alignment: .top)
    }

    private var sendTitle: String {
        guard selectedCount > 0 else { return "Nothing selected" }
        return "Send \(selectedCount) \(selectedCount == 1 ? "photo" : "photos")"
    }
}

// MARK: - PhotoThumbnailCell

struct PhotoThumbnailCell: View {
    let photo: PendingPhoto
    let fallbackColor: Color
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Group {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(fallbackColor)
                        .overlay(
                            Group {
                                if photo.asset != nil {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: photo.isVideo ? "video.fill" : "photo")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 22))
                                }
                            }
                        )
                }
            }
            .clipped()

            // Video indicator
            if photo.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
        }
        .task(id: photo.id) {
            guard let asset = photo.asset else { return }
            thumbnail = await loadThumbnail(asset: asset)
        }
    }

    private func loadThumbnail(asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            let size = CGSize(width: 300, height: 300)
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat  // single callback, no double-resume risk
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFill, options: opts
            ) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewPhotoGridView(
            photos: (0..<9).map {
                PendingPhoto(id: "p\($0)", sessionId: "s1", sessionName: "Preview",
                             captureDate: Date(), isSelected: true)
            }
        ) { _ in }
    }
}
