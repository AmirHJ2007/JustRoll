import SwiftUI
import Photos

struct ReviewPhotoGridView: View {
    @State private var photos: [PendingPhoto]
    var isSending: Bool
    let recipientNames: [String]
    let rollingWindow: (start: Date, end: Date)?
    let onSend: ([PendingPhoto]) -> Void

    init(
        photos: [PendingPhoto],
        isSending: Bool = false,
        recipientNames: [String] = [],
        rollingWindow: (start: Date, end: Date)? = nil,
        onSend: @escaping ([PendingPhoto]) -> Void
    ) {
        self._photos = State(initialValue: photos)
        self.isSending = isSending
        self.recipientNames = recipientNames
        self.rollingWindow = rollingWindow
        self.onSend = onSend
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)

    private var selectedPhotos: [PendingPhoto] { photos.filter(\.isSelected) }
    private var selectedCount: Int { selectedPhotos.count }
    private var allSelected: Bool { photos.allSatisfy(\.isSelected) }

    private var sessionId: String { photos.first?.sessionId ?? "" }
    private var sessionName: String { photos.first?.sessionName ?? "Your roll" }

    private let mockPalette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    // MARK: Phase
    private enum UploadPhase: Equatable { case review, developing, success }
    @State private var uploadPhase: UploadPhase = .review
    @State private var lastSentCount = 0
    @State private var sentPhotos: [PendingPhoto] = []

    // MARK: Grid entrance
    @State private var gridVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // ── Main review UI (always underneath) ──
            VStack(spacing: 0) {
                heroHeader
                privacyBanner
                photoGrid
                sendBar
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .disabled(uploadPhase != .review)

            // ── Film developing overlay (developing + success phases) ──
            if uploadPhase != .review {
                FilmDevelopingOverlay(
                    photos: sentPhotos,
                    batchId: sessionId,
                    palette: mockPalette
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(5)
            }

            // ── Success overlay ──
            if uploadPhase == .success {
                SendSuccessOverlay(count: lastSentCount)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: uploadPhase)
        .navigationTitle("Review your shots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let newValue = !allSelected
                    withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75)) {
                        for i in photos.indices { photos[i].isSelected = newValue }
                    }
                } label: {
                    Text(allSelected ? "Deselect all" : "Select all")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.accent)
                }
                .disabled(photos.isEmpty || uploadPhase != .review)
            }
        }
        .onAppear {
            guard !gridVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.82)) {
                    gridVisible = true
                }
            }
        }
        // Fallback: isSending → false means the upload completed (mock / no-UploadManager path)
        .onChange(of: isSending) { _, newValue in
            if !newValue && uploadPhase == .developing {
                triggerSuccess()
            }
        }
        // Real path: UploadManager finishes the batch
        .onChange(of: UploadManager.shared.completed[sessionId]) { _, done in
            if done == true && uploadPhase == .developing {
                triggerSuccess()
            }
        }
    }

    private func triggerSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeIn(duration: 0.25)) { uploadPhase = .success }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionName)
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if let window = rollingWindow {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(windowLabel(window.start, window.end))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 8)
            if !recipientNames.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    AvatarCluster(names: recipientNames, size: 26, maxVisible: 4)
                    Text(recipientNames.count == 1 ? "1 recipient" : "\(recipientNames.count) recipients")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 0.5)
        }
    }

    private func windowLabel(_ start: Date, _ end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let d = f.string(from: start)
        let dur = end.timeIntervalSince(start)
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        if h > 0 { return "\(d) · \(h)h \(m)m" }
        return "\(d) · \(max(1, m))m"
    }

    // MARK: - Privacy banner

    private var privacyBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.accent)
            Text("Tap any photo to remove it before sending")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accentPressed)
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.accent.opacity(0.55))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.accentTint)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Colors.accent.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Photo grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(photos.indices, id: \.self) { i in
                    PhotoGridCell(
                        photo: $photos[i],
                        index: i,
                        fallbackColor: mockPalette[photos[i].mockColorSeed % mockPalette.count],
                        gridVisible: gridVisible
                    )
                }
            }
            .padding(7)
        }
    }

    // MARK: - Send bar

    private var sendBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: 4) {
                Text("\(selectedCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(selectedCount > 0 ? Theme.Colors.accent : Theme.Colors.textMuted)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: selectedCount)
                Text("of \(photos.count) \(photos.count == 1 ? "shot" : "shots") selected")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            RollButton(title: sendButtonTitle, isLoading: false) {
                lastSentCount = selectedCount
                sentPhotos = selectedPhotos
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeIn(duration: 0.22)) { uploadPhase = .developing }
                onSend(selectedPhotos)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.2), value: selectedCount == 0)
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 0.5)
        }
    }

    private var sendButtonTitle: String {
        guard selectedCount > 0 else { return "Nothing selected" }
        return "Send \(selectedCount) \(selectedCount == 1 ? "shot" : "shots") →"
    }
}

// MARK: - FilmDevelopingOverlay
// Full-screen takeover that plays while the upload runs.
// Progress is driven by UploadManager.shared.progress[batchId].
// Falls back gracefully: if isSending flips to false (mock / error) the
// parent's onChange(of: isSending) will call triggerSuccess() instead.

private struct FilmDevelopingOverlay: View {
    let photos: [PendingPhoto]
    let batchId: String
    let palette: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTimeout = false

    // Reads directly from UploadManager — @Observable tracks this in body
    private var progress: Double {
        UploadManager.shared.progress[batchId] ?? 0
    }

    private var statusCopy: String {
        if progress < 0.33 { return "Developing your shots…" }
        if progress < 0.67 { return "Rolling them out…" }
        return "Almost there…"
    }

    var body: some View {
        ZStack {
            // Soft mint-to-white gradient backdrop
            LinearGradient(
                colors: [Color(hex: 0xE4F2E8), Color(hex: 0xF7FBF8), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Title + rotating Caveat copy
                VStack(spacing: 6) {
                    Text("Sending your roll")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(statusCopy)
                        .font(.custom("Caveat-Medium", size: 28))
                        .foregroundColor(Theme.Colors.accent)
                        .animation(
                            reduceMotion ? .none : .easeInOut(duration: 0.35),
                            value: statusCopy
                        )
                }

                // Film strip
                FilmStripView(photos: photos, palette: palette, progress: progress)
                    .frame(height: 96)
                    .padding(.horizontal, 16)

                // Progress bar + percentage
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.accent.opacity(0.14))
                            Capsule()
                                .fill(Theme.Colors.accent)
                                .frame(width: max(0, geo.size.width * CGFloat(progress)))
                                .animation(
                                    reduceMotion ? .none :
                                        .spring(response: 0.52, dampingFraction: 0.80),
                                    value: progress
                                )
                        }
                    }
                    .frame(height: 6)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundColor(Theme.Colors.textMuted)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: Int(progress * 100))
                }
                .padding(.horizontal, 40)

                // Timeout copy (appears after 30s with no completion)
                if showTimeout {
                    VStack(spacing: 6) {
                        Text("This is taking a while…")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Photos will finish uploading in the background.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Theme.Colors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
        }
        // Timeout watcher — cancelled automatically when overlay disappears
        .task {
            var elapsed = 0
            while elapsed < 30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                elapsed += 1
            }
            guard !showTimeout else { return }
            withAnimation(.spring(response: 0.4)) { showTimeout = true }
        }
    }
}

// MARK: - FilmStripView
// Horizontal scrollable strip with sprocket holes and developing frames.

private struct FilmStripView: View {
    let photos: [PendingPhoto]
    let palette: [Color]
    let progress: Double

    private var frameCount: Int { min(max(photos.count, 3), 10) }
    private var filledCount: Int { Int(ceil(Double(min(photos.count, frameCount)) * progress)) }

    var body: some View {
        ZStack {
            // Strip dark background
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0x1C1C1C))

            // Sprocket rows pinned to top and bottom
            VStack {
                sprocketRow
                Spacer()
                sprocketRow
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            // Horizontally scrollable frames
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<frameCount, id: \.self) { i in
                        FilmFrameCell(
                            photo: i < photos.count ? photos[i] : nil,
                            fallbackColor: palette[i % palette.count],
                            isDeveloped: i < filledCount
                        )
                        .frame(width: 42, height: 54)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private var sprocketRow: some View {
        HStack(spacing: 9) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.black)
                    .frame(width: 7, height: 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - FilmFrameCell
// A single frame in the strip. Transitions from dark (undeveloped) to
// colored/thumbnail (developed) as upload advances.

private struct FilmFrameCell: View {
    let photo: PendingPhoto?
    let fallbackColor: Color
    let isDeveloped: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if isDeveloped {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [fallbackColor.opacity(0.85), Theme.Colors.accent.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .transition(.opacity)
            } else {
                Color(hex: 0x2C2C2C)
                    .overlay(
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.11))
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.white.opacity(isDeveloped ? 0.18 : 0.05), lineWidth: 0.5)
        )
        .animation(.easeIn(duration: 0.38), value: isDeveloped)
        .onChange(of: isDeveloped) { _, nowDeveloped in
            if nowDeveloped { Task { await loadThumbnail() } }
        }
        .onAppear {
            if isDeveloped { Task { await loadThumbnail() } }
        }
    }

    private func loadThumbnail() async {
        guard let asset = photo?.asset, thumbnail == nil else { return }
        thumbnail = await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in cont.resume(returning: img) }
        }
    }
}

// MARK: - SendSuccessOverlay
// Full-screen confirmation: spring disc + drawn checkmark + particle burst.
// The film overlay fades out simultaneously as this appears.

private struct SendSuccessOverlay: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var discScale: CGFloat = 0.2
    @State private var discOpacity: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var textVisible = false
    @State private var burst = false

    private struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let symbol: String
    }

    private let particles: [Particle] = {
        let symbols = ["photo.fill", "paperplane.fill", "sparkle",
                       "photo.fill", "sparkle", "paperplane.fill",
                       "photo.fill", "sparkle", "camera.fill", "sparkle"]
        return symbols.enumerated().map { i, symbol in
            Particle(
                angle: Double(i) * (360.0 / Double(symbols.count)) + Double.random(in: -14...14),
                distance: CGFloat.random(in: 90...150),
                size: CGFloat.random(in: 13...22),
                symbol: symbol
            )
        }
    }()

    var body: some View {
        ZStack {
            // Light gradient backdrop — continuous with the film-developing screen underneath
            LinearGradient(
                colors: [Color(hex: 0xE4F2E8), Color(hex: 0xF7FBF8), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Particle burst
            if !reduceMotion {
                ForEach(particles) { p in
                    Image(systemName: p.symbol)
                        .font(.system(size: p.size, weight: .semibold))
                        .foregroundColor(Theme.Colors.accent.opacity(0.85))
                        .offset(
                            x: burst ? cos(p.angle * .pi / 180) * p.distance : 0,
                            y: burst ? sin(p.angle * .pi / 180) * p.distance : 0
                        )
                        .scaleEffect(burst ? 1 : 0.2)
                        .opacity(burst ? 0 : 0.9)
                        .rotationEffect(.degrees(burst ? Double.random(in: -40...40) : 0))
                }
            }

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.Colors.accent.opacity(0.45), radius: 24, x: 0, y: 8)

                    CheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        .frame(width: 44, height: 44)
                }
                .scaleEffect(discScale)
                .opacity(discOpacity)

                VStack(spacing: 6) {
                    Text("Sent!")
                        .font(.custom("Caveat-Medium", size: 44))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("\(count) \(count == 1 ? "shot is" : "shots are") landing in their camera rolls 🎞️")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 14)
                .scaleEffect(textVisible ? 1 : 0.92)
            }
            .padding(.horizontal, 40)
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.2)) {
                discScale = 1; discOpacity = 1; textVisible = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.15)) { checkProgress = 1 }
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            discScale = 1; discOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.32).delay(0.18)) { checkProgress = 1 }
        withAnimation(.easeOut(duration: 0.85).delay(0.28)) { burst = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.68).delay(0.35)) {
            textVisible = true
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.40, y: rect.height * 0.82))
        p.addLine(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.20))
        return p
    }
}

// MARK: - PhotoGridCell
// Extracted to own view so it carries its own bounce-animation state.
// Deselected photos scale to 0.94, dim, and show a hollow circle badge.
// Photos clip to 10pt continuous rounded corners; grid uses 7pt spacing.

private struct PhotoGridCell: View {
    @Binding var photo: PendingPhoto
    let index: Int
    let fallbackColor: Color
    var gridVisible: Bool

    @State private var bounceScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumbnailCell(photo: photo, fallbackColor: fallbackColor)
                .aspectRatio(1, contentMode: .fit)

            // Dim overlay when deselected
            if !photo.isSelected {
                Color.black.opacity(0.45)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
                        value: photo.isSelected
                    )
            }

            // Checkmark badge
            Image(systemName: photo.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(photo.isSelected ? Theme.Colors.accent : .white.opacity(0.85))
                .shadow(color: .black.opacity(0.35), radius: 2.5, x: 0, y: 1)
                .padding(6)
                .scaleEffect(photo.isSelected ? 1.18 : 1.0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.26, dampingFraction: 0.52),
                    value: photo.isSelected
                )
        }
        // Rounded corners on the cell
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // Scale down when deselected (springy)
        .scaleEffect(photo.isSelected ? 1.0 : 0.94)
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.72),
            value: photo.isSelected
        )
        // Tap bounce
        .scaleEffect(bounceScale)
        // Entrance stagger
        .opacity(gridVisible ? 1 : 0)
        .scaleEffect(gridVisible ? 1 : 0.86)
        .animation(
            reduceMotion ? .none :
                .spring(response: 0.46, dampingFraction: 0.74)
                .delay(Double(index % 12) * 0.038),
            value: gridVisible
        )
        .onTapGesture {
            photo.isSelected.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.48)) {
                bounceScale = 0.90
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.58).delay(0.1)) {
                bounceScale = 1.0
            }
        }
    }
}

// MARK: - PhotoThumbnailCell (unchanged — real PHAsset thumbnails + video badges)

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
            opts.deliveryMode = .highQualityFormat
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
                PendingPhoto(id: "p\($0)", sessionId: "s1", sessionName: "Friday night",
                             captureDate: Date(), isSelected: true)
            },
            recipientNames: ["Sara", "James", "Lena"],
            rollingWindow: (
                start: Date().addingTimeInterval(-3 * 3600),
                end: Date()
            )
        ) { _ in }
    }
}
