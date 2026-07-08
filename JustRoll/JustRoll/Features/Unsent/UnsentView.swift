import SwiftUI
import Photos

// MARK: - FannedPhotoStack
// Shows up to 3 "photo prints" fanned like a pile, most recent on top.

struct FannedPhotoStack: View {
    let photos: [PendingPhoto]
    var frameSize: CGFloat = 76

    private let palette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    private var stackPhotos: [PendingPhoto] { Array(photos.prefix(3)) }

    var body: some View {
        let n = stackPhotos.count
        ZStack {
            if n == 0 {
                // Placeholder when no photos yet
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.border, lineWidth: 0.5)
                    )
                    .overlay(
                        Image(systemName: "photo.stack")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.Colors.textMuted.opacity(0.4))
                    )
                    .frame(width: frameSize, height: frameSize)
            } else {
                // Back layer (index 2) — most rotated
                if n >= 3 {
                    FannedPhotoFrame(
                        photo: stackPhotos[2],
                        size: frameSize,
                        fallbackColor: palette[stackPhotos[2].mockColorSeed % palette.count]
                    )
                    .rotationEffect(.degrees(-8))
                    .offset(x: -5, y: 5)
                }
                // Middle layer (index 1)
                if n >= 2 {
                    FannedPhotoFrame(
                        photo: stackPhotos[1],
                        size: frameSize,
                        fallbackColor: palette[stackPhotos[1].mockColorSeed % palette.count]
                    )
                    .rotationEffect(.degrees(5))
                    .offset(x: 4, y: -3)
                }
                // Front layer (index 0) — on top, straight
                FannedPhotoFrame(
                    photo: stackPhotos[0],
                    size: frameSize,
                    fallbackColor: palette[stackPhotos[0].mockColorSeed % palette.count]
                )
                .rotationEffect(.degrees(0.5))
            }
        }
        .frame(width: frameSize + 20, height: frameSize + 20)
    }
}

private struct FannedPhotoFrame: View {
    let photo: PendingPhoto
    let size: CGFloat
    let fallbackColor: Color
    @State private var thumbnail: UIImage?

    private let borderSize: CGFloat = 5

    var body: some View {
        ZStack {
            // White "print" border
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)
                .frame(width: size + borderSize * 2, height: size + borderSize * 2)

            // Photo content
            Group {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(fallbackColor)
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: photo.isVideo ? "video.fill" : "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.75))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Video badge
            if photo.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            }
        }
        .task(id: photo.id) {
            guard let asset = photo.asset else { return }
            thumbnail = await loadThumbnail(asset: asset)
        }
    }

    private func loadThumbnail(asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 160, height: 160),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in cont.resume(returning: img) }
        }
    }
}

// MARK: - UnsentCard

struct UnsentCard: View {
    let batch: PendingBatch
    let onReview: () -> Void
    var onDiscard: () -> Void = {}
    @State private var showDiscardConfirm = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var uploadProgress: Double? { UploadManager.shared.progress[batch.id] }
    private var isUploading: Bool { uploadProgress != nil && !(UploadManager.shared.completed[batch.id] ?? false) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection
            recipientsRow
            if isUploading {
                uploadingSection
            } else {
                actionSection
            }
        }
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) { discardButton }
        .confirmationDialog(
            "Don't send this roll?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Don't send", role: .destructive) { onDiscard() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("These shots won't be shared with anyone, and this card goes away for good.")
        }
        .allowsHitTesting(!isUploading)
    }

    // MARK: Discard ("don't send") button

    private var discardButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showDiscardConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textMuted)
                .padding(8)
                .background(Theme.Colors.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 0.5))
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
        .padding(10)
        .accessibilityLabel("Don't send this roll")
    }

    // MARK: Hero — fanned photo stack + session metadata

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 14) {
            // Fanned photo stack with count badge (badge hidden when 0)
            ZStack(alignment: .bottomTrailing) {
                FannedPhotoStack(photos: batch.photos, frameSize: 76)

                if batch.photos.count > 0 {
                    Text("\(batch.photos.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                        .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 4, x: 0, y: 2)
                        .offset(x: 4, y: 4)
                }
            }

            // Session info
            VStack(alignment: .leading, spacing: 6) {
                Text(batch.sessionName)
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)

                // Photo count line (shown when photos exist)
                let c = batch.photos.count
                if c > 0 {
                    Text("\(c) \(c == 1 ? "shot" : "shots") to review")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.accent)
                }

                // Duration row
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                    Text(windowString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: Recipients row

    private var recipientsRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.textMuted)
            Text(recipientLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            AvatarCluster(names: batch.recipientNames, size: 22, maxVisible: 3, avatarIds: batch.recipientAvatarIds)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Theme.Colors.surface)
    }

    // MARK: Upload progress section

    private var uploadingSection: some View {
        let pct = Int((uploadProgress ?? 0) * 100)
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                Text("Uploading \(pct)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
                Spacer()
            }
            ProgressView(value: uploadProgress ?? 0)
                .progressViewStyle(.linear)
                .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.Colors.accentTint)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 20,
            bottomTrailingRadius: 20, topTrailingRadius: 0
        ))
    }

    // MARK: Action button

    private var actionSection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onReview()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Review & send")
                    .font(Theme.Typography.label)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.Colors.accent)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 20,
                topTrailingRadius: 0
            ))
            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
    }

    // MARK: Helpers

    private var windowString: String {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "MMM d"
        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short
        let start = timeFmt.string(from: batch.rollingStartedAt)
        let end   = timeFmt.string(from: batch.rollingStoppedAt)
        if Calendar.current.isDate(batch.rollingStartedAt, inSameDayAs: batch.rollingStoppedAt) {
            return "\(dayFmt.string(from: batch.rollingStartedAt)) · \(start) – \(end)"
        }
        // Roll crossed midnight — show both days so the window reads right.
        return "\(dayFmt.string(from: batch.rollingStartedAt)) \(start) – \(dayFmt.string(from: batch.rollingStoppedAt)) \(end)"
    }

    private var recipientLabel: String {
        let names = batch.recipientNames
        switch names.count {
        case 0: return "No recipients"
        case 1: return names[0]
        case 2: return "\(names[0]) & \(names[1])"
        case 3: return "\(names[0]), \(names[1]) & \(names[2])"
        default: return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
    }
}

// MARK: - UnsentView

struct UnsentView: View {
    var viewModel: UnsentViewModel
    @State private var reviewBatch: PendingBatch?
    @State private var showingReview = false
    @State private var listVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.zIndex(1)

                    Group {
                        if viewModel.isLoading {
                            Spacer()
                            FilmReelSpinner()
                            Spacer()
                        } else if viewModel.pendingBatches.isEmpty {
                            emptyState
                        } else {
                            batchList
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.load()
                withAnimation(reduceMotion ? .none : .spring(response: 0.45)) {
                    listVisible = true
                }
            }
            .onChange(of: showingReview) { _, reviewing in
                viewModel.isReviewing = reviewing
            }
            .onChange(of: viewModel.pendingReviewSessionId) { _, sessionId in
                guard let sessionId else { return }
                defer { viewModel.pendingReviewSessionId = nil }
                // Several unsent cards can share a sessionId (one circle, multiple rolls) —
                // the freshest stop-rolling is the one just requested, so pick the latest.
                guard let batch = viewModel.pendingBatches
                    .filter({ $0.sessionId == sessionId })
                    .max(by: { $0.rollingStoppedAt < $1.rollingStoppedAt }) else { return }
                reviewBatch = batch
                showingReview = true
            }
            .navigationDestination(isPresented: $showingReview) {
                if let batch = reviewBatch {
                    ReviewPhotoGridView(
                        photos: batch.photos,
                        isSending: viewModel.isSending,
                        sendFailed: viewModel.errorMessage != nil,
                        recipientNames: batch.recipientNames,
                        recipientAvatarIds: batch.recipientAvatarIds,
                        rollingWindow: (start: batch.rollingStartedAt, end: batch.rollingStoppedAt),
                        batchId: batch.id,
                        onSend: { selected in
                            Task {
                                await viewModel.sendPhotos(selected, from: batch)
                                if viewModel.errorMessage != nil {
                                    // ReviewPhotoGridView already reverted to review and is
                                    // showing its own "Couldn't send" alert — stay put so the
                                    // user can retry, and don't also pop the generic alert.
                                    viewModel.errorMessage = nil
                                } else {
                                    // Let the film-developing + success animation finish before popping
                                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                                    showingReview = false
                                }
                            }
                        },
                        onDiscard: {
                            Task {
                                await viewModel.discardBatch(batch)
                                // On failure the view model's alert explains; stay on the
                                // review screen so nothing silently disappears.
                                if viewModel.errorMessage == nil { showingReview = false }
                            }
                        }
                    )
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        PageHeader(title: "Unsent", subtitle: headerSubtitle)
    }

    private var headerSubtitle: String? {
        guard !viewModel.pendingBatches.isEmpty else { return nil }
        let total = viewModel.totalPhotoCount
        if total > 0 {
            return "\(total) \(total == 1 ? "photo" : "photos") waiting"
        }
        let n = viewModel.pendingBatches.count
        return "\(n) \(n == 1 ? "roll" : "rolls") to review"
    }

    // MARK: Batch list

    private var batchList: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 8)

                ForEach(Array(viewModel.pendingBatches.enumerated()), id: \.element.id) { idx, batch in
                    UnsentCard(
                        batch: batch,
                        onReview: {
                            reviewBatch = batch
                            showingReview = true
                        },
                        onDiscard: {
                            Task { await viewModel.discardBatch(batch) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .opacity(listVisible ? 1 : 0)
                    .offset(y: listVisible ? 0 : 28)
                    .animation(
                        reduceMotion ? .none :
                            .spring(response: 0.52, dampingFraction: 0.80)
                            .delay(Double(idx) * 0.10),
                        value: listVisible
                    )
                    .transition(
                        reduceMotion ? .opacity :
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            )
                    )
                }

                Spacer().frame(height: 48)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewModel.pendingBatches.map(\.id))
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
                UnsentEmptyAnimation()

                // Copy
                VStack(spacing: Theme.Spacing.sm) {
                    Text("All caught up!")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Go make some memories — shots from your\nrolls will show up here to review before they go out.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            Spacer()
        }
        .opacity(listVisible ? 1 : 0)
        .animation(reduceMotion ? .none : .easeIn(duration: 0.4), value: listVisible)
    }
}

// MARK: - UnsentEmptyAnimation

private struct UnsentEmptyAnimation: View {
    @State private var floating = false
    @State private var sparkle1 = false
    @State private var sparkle2 = false
    @State private var sparkle3 = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            sparkleView(offset: CGSize(width: -52, height: -30), visible: sparkle1)
            sparkleView(offset: CGSize(width: 54, height: -38), visible: sparkle2)
            sparkleView(offset: CGSize(width: 46, height: 28),  visible: sparkle3)

            ZStack {
                Circle()
                    .fill(Theme.Colors.accentTint)
                    .frame(width: 112, height: 112)
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent)
            }
            .offset(y: floating ? -8 : 0)
            .shadow(color: Theme.Colors.accent.opacity(0.18), radius: floating ? 18 : 8, x: 0, y: floating ? 10 : 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floating = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.0)) { sparkle1 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) { sparkle2 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.8)) { sparkle3 = true }
        }
    }

    private func sparkleView(offset: CGSize, visible: Bool) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Theme.Colors.accent.opacity(visible ? 0.8 : 0.2))
            .scaleEffect(visible ? 1 : 0.5)
            .offset(offset)
    }
}

#Preview {
    UnsentView(viewModel: UnsentViewModel())
}
