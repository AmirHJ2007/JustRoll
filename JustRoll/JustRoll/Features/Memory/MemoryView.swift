import SwiftUI

// MARK: - MemoryView

struct MemoryView: View {
    var viewModel: MemoryViewModel
    @State private var cardsVisible = false
    @State private var reviewBatch: ReceivedBatch?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: MemoryViewModel) {
        self.viewModel = viewModel
    }

    private var totalPhotoCount: Int { viewModel.batches.reduce(0) { $0 + $1.photos.count } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    PageHeader(
                        title: headerTitle,
                        subtitle: viewModel.batches.isEmpty ? nil : headerSubtitle
                    )
                    if viewModel.isLoading && viewModel.batches.isEmpty {
                        Spacer()
                        FilmReelSpinner()
                        Spacer()
                    } else if viewModel.batches.isEmpty {
                        emptyState
                    } else {
                        batchList
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await load() }
            .sheet(item: $reviewBatch) { batch in
                ReceivedReviewView(batch: batch) { savedPhotos, dismissedPhotos in
                    Task {
                        // DB bookkeeping only — download+save happens inside ReceivedReviewView.
                        // Photos that failed to save are in neither list, so their
                        // deliveries stay pending and they resurface on the next fetch.
                        let savedIds = savedPhotos.map(\.id)
                        let dismissedIds = dismissedPhotos.map(\.id)
                        await viewModel.markSaved(
                            batch: batch,
                            savedPhotoIds: savedIds,
                            dismissedPhotoIds: dismissedIds
                        )
                        reviewBatch = nil
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerTitle: String { "My Memories" }

    private var headerSubtitle: String {
        let b = viewModel.batches.count
        let p = totalPhotoCount
        return "\(b) \(b == 1 ? "batch" : "batches") · \(p) \(p == 1 ? "photo" : "photos")"
    }

    // MARK: - Batch list

    private var batchList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(viewModel.batches.enumerated()), id: \.element.id) { idx, batch in
                    ReceivedBatchCard(
                        batch: batch,
                        cardVisible: cardsVisible,
                        delay: Double(idx) * 0.08
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        reviewBatch = batch
                    }
                    .padding(.horizontal, 16)
                }
                Spacer().frame(height: 28)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            MemoryEmptyAnimation()
            VStack(spacing: Theme.Spacing.sm) {
                Text("Nothing here yet")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("When friends roll and share their shots,\nthey'll land here waiting for you.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Load

    private func load() async {
        await viewModel.load()
        guard !reduceMotion else { cardsVisible = true; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cardsVisible = true
            }
        }
    }
}

// MARK: - ReceivedBatchCard

private struct ReceivedBatchCard: View {
    let batch: ReceivedBatch
    var cardVisible: Bool
    var delay: Double
    let onReview: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let palette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    private var timeWindow: String {
        let startFmt = DateFormatter()
        startFmt.dateFormat = "h:mm"
        let endFmt = DateFormatter()
        endFmt.dateFormat = "h:mm a"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE d MMM"
        let day = dayFmt.string(from: batch.rollingStartedAt)
        let start = startFmt.string(from: batch.rollingStartedAt)
        let end = endFmt.string(from: batch.rollingStoppedAt)
        return "\(day) · \(start) – \(end)"
    }

    var body: some View {
        Button(action: onReview) {
            VStack(alignment: .leading, spacing: 0) {
                // Photo hero with overlapping sender avatar
                ZStack(alignment: .bottomLeading) {
                    photoHero
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20, bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0, topTrailingRadius: 20,
                                style: .continuous
                            )
                        )
                    AvatarView(name: batch.senderName, size: 46, avatarId: batch.senderAvatarId)
                        .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 3))
                        .offset(x: 16, y: 23)
                        .zIndex(2)
                }

                cardBody
            }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        batch.isSaved
                            ? Theme.Colors.border
                            : Theme.Colors.accent.opacity(0.3),
                        lineWidth: batch.isSaved ? 0.5 : 1
                    )
            )
            // Base shadow
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            // Soft green glow for unsaved batches
            .shadow(
                color: batch.isSaved ? .clear : Theme.Colors.accent.opacity(0.18),
                radius: 18, x: 0, y: 6
            )
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        // Entrance animation
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 22)
        .animation(
            reduceMotion ? .none :
                .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
            value: cardVisible
        )
    }

    // MARK: Photo hero — fan of polaroid-style cards

    private var photoHero: some View {
        let preview = Array(batch.photos.prefix(3))
        return ZStack {
            // Tinted background behind the fan
            Theme.Colors.accentTint

            if preview.isEmpty {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent.opacity(0.3))
            } else {
                ForEach(Array(preview.enumerated()), id: \.element.id) { i, photo in
                    fanCard(photo: photo, index: i, total: preview.count)
                }
            }

            // "NEW" badge for unsaved batches
            if !batch.isSaved {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.accent)
                            .clipShape(Capsule())
                            .padding(.top, 14)
                            .padding(.trailing, 14)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 164)
    }

    private func fanCard(photo: ReceivedPhoto, index: Int, total: Int) -> some View {
        let rotations: [Double]
        let xOffsets: [CGFloat]
        let yOffsets: [CGFloat]

        switch total {
        case 1:
            rotations = [2]
            xOffsets  = [0]
            yOffsets  = [0]
        case 2:
            rotations = [-10, 7]
            xOffsets  = [-22, 20]
            yOffsets  = [6, -4]
        default:
            rotations = [-13, -2, 11]
            xOffsets  = [-32, -4, 26]
            yOffsets  = [8, -6, 4]
        }

        let rot  = index < rotations.count ? rotations[index] : 0
        let xOff = index < xOffsets.count  ? xOffsets[index]  : 0
        let yOff = index < yOffsets.count  ? yOffsets[index]  : 0

        return Group {
            if let url = photo.thumbnailUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackTile(photo: photo)
                    }
                }
            } else {
                fallbackTile(photo: photo)
            }
        }
        .frame(width: 84, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
        .rotationEffect(.degrees(rot))
        .offset(x: xOff, y: yOff)
        .zIndex(Double(index))
    }

    @ViewBuilder
    private func fallbackTile(photo: ReceivedPhoto) -> some View {
        Rectangle()
            .fill(palette[photo.mockColorSeed % palette.count])
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.45))
            )
    }

    // MARK: Card body

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Sender name + photo count (extra top padding for avatar overlap)
            HStack(alignment: .firstTextBaseline) {
                Text("\(batch.senderName)'s shots")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                photoBadge
            }

            // Circle / session name
            HStack(spacing: 5) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.accent)
                Text(batch.sessionName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Time window
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
                Text(timeWindow)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            reviewCTA
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)    // room for the avatar that overlaps from above
        .padding(.bottom, 16)
    }

    private var photoBadge: some View {
        let n = batch.photos.count
        return Text("\(n) \(n == 1 ? "shot" : "shots")")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(batch.isSaved ? Theme.Colors.textMuted : Theme.Colors.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(batch.isSaved ? Theme.Colors.surface : Theme.Colors.accentTint)
            .clipShape(Capsule())
    }

    private var reviewCTA: some View {
        HStack(spacing: 6) {
            if batch.isSaved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Saved to camera roll")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            } else {
                Text("Review & Save to Camera Roll")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundColor(batch.isSaved ? Theme.Colors.textMuted : .white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(batch.isSaved ? Theme.Colors.surface : Theme.Colors.accent)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(batch.isSaved ? Theme.Colors.border : Color.clear, lineWidth: 0.5)
        )
        .padding(.top, 2)
    }
}

// MARK: - Memory empty animation

private struct MemoryEmptyAnimation: View {
    @State private var floating = false
    @State private var sparkle1 = false
    @State private var sparkle2 = false
    @State private var sparkle3 = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            sparkleView(offset: CGSize(width: -52, height: -30), visible: sparkle1, delay: 0)
            sparkleView(offset: CGSize(width: 54, height: -38), visible: sparkle2, delay: 0.4)
            sparkleView(offset: CGSize(width: 46, height: 28), visible: sparkle3, delay: 0.8)

            ZStack {
                Circle()
                    .fill(Theme.Colors.accentTint)
                    .frame(width: 112, height: 112)
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent)
            }
            .offset(y: floating ? -8 : 0)
            .shadow(color: Theme.Colors.accent.opacity(0.18), radius: floating ? 18 : 8, x: 0, y: floating ? 10 : 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floating = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0))   { sparkle1 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) { sparkle2 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.8)) { sparkle3 = true }
        }
    }

    private func sparkleView(offset: CGSize, visible: Bool, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Theme.Colors.accent.opacity(visible ? 0.8 : 0.2))
            .scaleEffect(visible ? 1 : 0.5)
            .offset(offset)
    }
}

#Preview {
    MemoryView(viewModel: MemoryViewModel())
}
