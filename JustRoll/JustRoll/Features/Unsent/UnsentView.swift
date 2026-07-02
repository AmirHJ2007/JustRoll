import SwiftUI

// MARK: - CountdownChip

struct CountdownChip: View {
    let expiresAt: Date
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timeLeft: TimeInterval { expiresAt.timeIntervalSinceNow }
    private var isUrgent: Bool { timeLeft > 0 && timeLeft < 24 * 3600 }
    private var isExpired: Bool { timeLeft <= 0 }

    private var label: String {
        if isExpired { return "Expired" }
        let days = Int(timeLeft / 86400)
        if days >= 1 { return "\(days)d left" }
        let hours = Int(timeLeft / 3600)
        if hours >= 1 { return "\(hours)h left" }
        let mins = max(1, Int(timeLeft / 60))
        return "\(mins)m left"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(isUrgent || isExpired ? Theme.Colors.danger : Theme.Colors.accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            (isUrgent || isExpired)
                ? Theme.Colors.danger.opacity(0.12)
                : Theme.Colors.accentTint
        )
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                (isUrgent || isExpired) ? Theme.Colors.danger.opacity(0.35) : Theme.Colors.accent.opacity(0.25),
                lineWidth: 0.5
            )
        )
        .scaleEffect(pulsing ? 1.05 : 1)
        .onAppear {
            guard isUrgent && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - ThumbnailPreviewStrip

struct ThumbnailPreviewStrip: View {
    let photos: [PendingPhoto]

    private let palette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]
    private let maxVisible = 4
    private let thumbSize: CGFloat = 62
    private let radius: CGFloat = 10

    private var visiblePhotos: [PendingPhoto] { Array(photos.prefix(maxVisible)) }
    private var overflow: Int {
        guard photos.count > maxVisible else { return 0 }
        return photos.count - (maxVisible - 1)
    }
    private var showOverflow: Bool { photos.count > maxVisible }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(visiblePhotos.enumerated()), id: \.element.id) { idx, photo in
                let isOverflowSlot = showOverflow && idx == maxVisible - 1
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(palette[photo.mockColorSeed % palette.count])
                        .frame(width: thumbSize, height: thumbSize)

                    if !isOverflowSlot {
                        Image(systemName: photo.isVideo ? "play.circle.fill" : "photo")
                            .font(.system(size: photo.isVideo ? 20 : 16))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if isOverflowSlot {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Color.black.opacity(0.38))
                        Text("+\(overflow)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: radius))
            }

            Spacer()
        }
    }
}

// MARK: - RecipientAvatarsRow

struct RecipientAvatarsRow: View {
    let names: [String]
    private let maxVisible = 4
    private let size: CGFloat = 26

    private var visible: [String] { Array(names.prefix(maxVisible)) }
    private var overflow: Int { max(0, names.count - maxVisible) }

    var body: some View {
        HStack(spacing: -7) {
            ForEach(visible, id: \.self) { name in
                AvatarView(name: name, size: size)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 1.5))
            }
            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.surface)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 1.5))
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
    }
}

// MARK: - UnsentCard

struct UnsentCard: View {
    let batch: PendingBatch
    let onReview: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            divider
            thumbnailSection
            divider
            detailsSection
            divider
            recipientsSection
            divider
            actionSection
        }
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(batch.sessionName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                let c = batch.photos.count
                Text("\(c) \(c == 1 ? "photo" : "photos") waiting")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            CountdownChip(expiresAt: batch.expiresAt)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: Thumbnails

    private var thumbnailSection: some View {
        ThumbnailPreviewStrip(photos: batch.photos)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    // MARK: Roll details

    private var detailsSection: some View {
        HStack(spacing: 20) {
            detailItem(icon: "play.circle.fill", label: "Started", value: timeString(batch.rollingStartedAt))
            detailItem(icon: "stop.circle.fill", label: "Ended", value: dateTimeString(batch.rollingStoppedAt))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.accent.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: Recipients

    private var recipientsSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)
            Text("Going to")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textMuted)
            RecipientAvatarsRow(names: batch.recipientNames)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: Action

    private var actionSection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onReview()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 15, weight: .semibold))
                Text("Review & send")
                    .font(Theme.Typography.label)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.Colors.accent)
            .clipShape(Capsule())
            .shadow(color: Theme.Colors.accent.opacity(0.28), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Helpers

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    private func dateTimeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a, MMM d"
        return f.string(from: d)
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
            .navigationDestination(isPresented: $showingReview) {
                if let batch = reviewBatch {
                    ReviewPhotoGridView(
                        photos: batch.photos,
                        isSending: viewModel.isSending
                    ) { selected in
                        Task {
                            await viewModel.sendPhotos(selected)
                            showingReview = false
                        }
                    }
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
        PageHeader(
            title: "Unsent",
            subtitle: viewModel.pendingBatches.isEmpty ? nil :
                "\(viewModel.totalPhotoCount) \(viewModel.totalPhotoCount == 1 ? "photo" : "photos") waiting"
        )
    }

    // MARK: Batch list

    private var batchList: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer().frame(height: 8)

                ForEach(Array(viewModel.pendingBatches.enumerated()), id: \.element.id) { idx, batch in
                    UnsentCard(batch: batch) {
                        reviewBatch = batch
                        showingReview = true
                    }
                    .padding(.horizontal, 16)
                    .opacity(listVisible ? 1 : 0)
                    .offset(y: listVisible ? 0 : 24)
                    .animation(
                        reduceMotion ? .none :
                            .spring(response: 0.5, dampingFraction: 0.82)
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

                Spacer().frame(height: 40)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewModel.pendingBatches.map(\.id))
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: Theme.Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentTint)
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 42))
                        .foregroundColor(Theme.Colors.accent)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text("You're all caught up")
                        .font(Theme.Typography.heading)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Photos from your rolls will\nshow up here to review before they go out.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            Spacer()
        }
        .opacity(listVisible ? 1 : 0)
        .animation(reduceMotion ? .none : .easeIn(duration: 0.4), value: listVisible)
    }
}

#Preview {
    UnsentView(viewModel: UnsentViewModel())
}
