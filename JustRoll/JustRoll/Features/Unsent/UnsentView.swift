import SwiftUI

struct UnsentView: View {
    @State private var viewModel = UnsentViewModel()
    @State private var reviewBatch: (sessionId: String, photos: [PendingPhoto])?
    @State private var showingReview = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    PageHeader(
                        title: "Unsent",
                        subtitle: viewModel.pendingPhotos.isEmpty ? nil :
                            "\(viewModel.pendingPhotos.count) \(viewModel.pendingPhotos.count == 1 ? "photo" : "photos") waiting"
                    )
                    .zIndex(1)
                    Group {
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                            Spacer()
                        } else if viewModel.pendingPhotos.isEmpty {
                            emptyState
                        } else {
                            batchList
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await viewModel.load() }
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 52))
                .foregroundColor(Theme.Colors.textMuted)
            VStack(spacing: Theme.Spacing.sm) {
                Text("Nothing to send")
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("When you end a roll, photos from that window show up here for you to review before they go out.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }
            Spacer()
        }
    }

    // MARK: - Batch list

    private var batchList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Spacer().frame(height: Theme.Spacing.lg)

                ForEach(viewModel.groupedBySession, id: \.sessionId) { group in
                    batchCard(group: group)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                Spacer().frame(height: Theme.Spacing.xxl)
            }
        }
    }

    private func batchCard(group: (sessionName: String, sessionId: String, photos: [PendingPhoto])) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(group.sessionName)
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textPrimary)

                        let count = group.photos.count
                        Text("\(count) \(count == 1 ? "photo" : "photos") waiting to review")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    // Thumbnail strip (first 3 photos as colour swatches)
                    thumbnailStrip(photos: Array(group.photos.prefix(3)))
                }

                RollButton(title: "Review & send") {
                    reviewBatch = (group.sessionId, group.photos)
                    showingReview = true
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private let mockPalette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    private func thumbnailStrip(photos: [PendingPhoto]) -> some View {
        HStack(spacing: -8) {
            ForEach(photos.reversed()) { photo in
                RoundedRectangle(cornerRadius: 6)
                    .fill(mockPalette[photo.mockColorSeed % mockPalette.count])
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.background, lineWidth: 2))
            }
        }
    }
}

#Preview {
    UnsentView()
}
