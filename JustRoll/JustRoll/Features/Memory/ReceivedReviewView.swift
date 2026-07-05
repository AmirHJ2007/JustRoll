import SwiftUI
import Photos

struct ReceivedReviewView: View {
    @State private var photos: [ReceivedPhoto]
    let batchName: String
    let senderName: String
    let senderAvatarId: Int?
    let rollingWindow: (start: Date, end: Date)
    let onSave: ([ReceivedPhoto]) -> Void

    init(batch: ReceivedBatch, onSave: @escaping ([ReceivedPhoto]) -> Void) {
        self._photos = State(initialValue: batch.photos)
        self.batchName = batch.sessionName
        self.senderName = batch.senderName
        self.senderAvatarId = batch.senderAvatarId
        self.rollingWindow = (batch.rollingStartedAt, batch.rollingStoppedAt)
        self.onSave = onSave
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)
    private let palette: [Color] = [
        Color(hex: 0x8EC5A2), Color(hex: 0xF4A261), Color(hex: 0xA8DADC),
        Color(hex: 0xC8A2C8), Color(hex: 0xF7D59C), Color(hex: 0xE8A598),
        Color(hex: 0x7EC8E3), Color(hex: 0xB7C9A8),
    ]

    private var selectedPhotos: [ReceivedPhoto] { photos.filter(\.isSelected) }
    private var selectedCount: Int { selectedPhotos.count }
    private var allSelected: Bool { photos.allSatisfy(\.isSelected) }

    // MARK: Phase
    private enum SavePhase: Equatable { case review, saving, success }
    @State private var savePhase: SavePhase = .review
    @State private var savingPhotos: [ReceivedPhoto] = []
    @State private var savedCount = 0
    @State private var lastSavedCount = 0

    // MARK: Grid entrance
    @State private var gridVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Main review UI (always underneath) ──
                VStack(spacing: 0) {
                    heroHeader
                    privacyBanner
                    photoGrid
                    saveBar
                }
                .background(Theme.Colors.background.ignoresSafeArea())
                .disabled(savePhase != .review)

                // ── Saving-to-roll overlay (saving + success phases) ──
                if savePhase != .review {
                    SavingToRollOverlay(
                        photos: savingPhotos,
                        savedCount: savedCount,
                        palette: palette
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(5)
                }

                // ── Success overlay ──
                if savePhase == .success {
                    SaveSuccessOverlay(count: lastSavedCount)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: savePhase)
            .navigationTitle("Review & save")
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
                    .disabled(photos.isEmpty || savePhase != .review)
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
            .interactiveDismissDisabled(savePhase != .review)
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            AvatarView(name: senderName, size: 42, avatarId: senderAvatarId)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(senderName)'s shots")
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.accent)
                        Text(batchName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(windowLabel(rollingWindow.start, rollingWindow.end))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 8)
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
            Text("Tap any photo to remove it before saving")
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
                    ReceivedPhotoGridCell(
                        photo: $photos[i],
                        index: i,
                        fallbackColor: palette[photos[i].mockColorSeed % palette.count],
                        gridVisible: gridVisible
                    )
                }
            }
            .padding(7)
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
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

            RollButton(title: saveButtonTitle, isLoading: false) {
                startSaving()
            }
            .disabled(selectedCount == 0 || savePhase != .review)
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

    private var saveButtonTitle: String {
        guard selectedCount > 0 else { return "Nothing selected" }
        return "Save \(selectedCount) \(selectedCount == 1 ? "shot" : "shots") to Camera Roll"
    }

    // MARK: - Save flow (download + PHPhotoLibrary, with real progress)

    private func startSaving() {
        let toSave = selectedPhotos
        guard !toSave.isEmpty else { return }
        savingPhotos = toSave
        savedCount = 0
        lastSavedCount = toSave.count
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeIn(duration: 0.22)) { savePhase = .saving }

        Task {
            for photo in toSave {
                // Download full-res + save to camera roll.
                // Failures (or nil URLs in mock) just skip — still counted as processed.
                if let url = photo.fullResUrl,
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    try? await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }

                // Pacing floor so each flight reads, even when a photo completes
                // instantly (mock nil URLs, cached downloads).
                if !reduceMotion {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }

                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.72)) {
                    savedCount += 1
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // Let the last shot finish its flight before celebrating
            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeIn(duration: 0.25)) { savePhase = .success }

            // Hold on the success overlay, then hand off to the parent
            // (markBatchSaved + local isSaved state + sheet dismissal).
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            onSave(toSave)
        }
    }
}

// MARK: - ReceivedPhotoGridCell

private struct ReceivedPhotoGridCell: View {
    @Binding var photo: ReceivedPhoto
    let index: Int
    let fallbackColor: Color
    var gridVisible: Bool

    @State private var bounceScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail — real URL or colour placeholder
            Group {
                if let url = photo.thumbnailUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Rectangle().fill(fallbackColor)
                                .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.5)))
                        case .empty:
                            Rectangle().fill(fallbackColor)
                                .overlay(ProgressView().tint(.white))
                        @unknown default:
                            Rectangle().fill(fallbackColor)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(fallbackColor)
                        .overlay(
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.45))
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            // Dim overlay when deselected
            if !photo.isSelected {
                Color.black.opacity(0.45)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
                        value: photo.isSelected
                    )
            }

            // Checkmark badge (hollow circle when deselected)
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
            withAnimation(.spring(response: 0.18, dampingFraction: 0.48)) { bounceScale = 0.90 }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.58).delay(0.1)) { bounceScale = 1.0 }
        }
    }
}

// MARK: - SavingToRollOverlay
// Full-screen takeover while photos download + save to the camera roll.
// Small thumbnails fly one by one into a camera-roll tray as each photo
// finishes; progress is real (savedCount / total).

private struct SavingToRollOverlay: View {
    let photos: [ReceivedPhoto]
    let savedCount: Int
    let palette: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flying: [FlyingShot] = []
    @State private var traySquash = false

    private struct FlyingShot: Identifiable, Equatable {
        let id: Int          // photo index — one flight per landed photo
        let startX: CGFloat
        let startRotation: Double
        let endRotation: Double
    }

    private var total: Int { max(photos.count, 1) }
    private var progress: Double { Double(savedCount) / Double(total) }

    private var statusCopy: String {
        if progress < 0.34 { return "Catching your shots…" }
        if progress < 0.75 { return "Tucking them into your roll…" }
        return "Almost yours…"
    }

    var body: some View {
        ZStack {
            // Soft mint-to-white gradient backdrop (matches sender's developing screen)
            LinearGradient(
                colors: [Color(hex: 0xE4F2E8), Color(hex: 0xF7FBF8), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Title + rotating Caveat copy
                VStack(spacing: 6) {
                    Text("Saving to your camera roll")
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
                .padding(.top, 40)

                Spacer()

                // Flight zone: thumbs drop from the top into the tray at the bottom
                ZStack(alignment: .bottom) {
                    Color.clear

                    // Flying thumbnails (skipped under reduceMotion)
                    if !reduceMotion {
                        ForEach(flying) { shot in
                            FlyingShotView(
                                photo: shot.id < photos.count ? photos[shot.id] : nil,
                                fallbackColor: palette[fallbackSeed(shot.id) % palette.count],
                                startX: shot.startX,
                                startRotation: shot.startRotation,
                                endRotation: shot.endRotation
                            )
                            .padding(.bottom, 22)   // aim at the tray's mouth
                        }
                    }

                    trayIcon
                }
                .frame(height: 260)
                .padding(.horizontal, 24)

                // Counter + real progress bar
                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Text("\(savedCount)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.accent)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: savedCount)
                        Text("of \(photos.count) saved")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

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
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 72)
            }
        }
        .onChange(of: savedCount) { _, newCount in
            guard !reduceMotion, newCount > 0 else { return }
            launchShot(index: newCount - 1)
        }
    }

    // MARK: Tray

    private var trayIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.background)
                .frame(width: 88, height: 74)
                .shadow(color: Theme.Colors.accent.opacity(0.25), radius: 16, x: 0, y: 6)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.accent.opacity(0.35), lineWidth: 1)
                .frame(width: 88, height: 74)
            Image(systemName: "photo.stack")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(Theme.Colors.accent)
        }
        // Squash bounce on each catch
        .scaleEffect(x: traySquash ? 1.12 : 1.0, y: traySquash ? 0.86 : 1.0, anchor: .bottom)
        .animation(.spring(response: 0.22, dampingFraction: 0.5), value: traySquash)
    }

    // MARK: Flight orchestration

    private func launchShot(index: Int) {
        let shot = FlyingShot(
            id: index,
            startX: CGFloat.random(in: -70...70),
            startRotation: Double.random(in: -22...22),
            endRotation: Double.random(in: -8...8)
        )
        flying.append(shot)

        // Squash the tray when the shot arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            traySquash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                traySquash = false
            }
        }
        // Clean up finished flights
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            flying.removeAll { $0.id == shot.id }
        }
    }

    private func fallbackSeed(_ index: Int) -> Int {
        index < photos.count ? photos[index].mockColorSeed : index
    }
}

// MARK: - FlyingShotView
// A single small thumbnail that arcs down from the top of the flight zone
// into the tray: springy drop, slight rotation, shrink + fade on arrival.

private struct FlyingShotView: View {
    let photo: ReceivedPhoto?
    let fallbackColor: Color
    let startX: CGFloat
    let startRotation: Double
    let endRotation: Double

    @State private var landed = false
    @State private var absorbed = false

    var body: some View {
        Group {
            if let url = photo?.thumbnailUrl {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallbackTile
                    }
                }
            } else {
                fallbackTile
            }
        }
        .frame(width: 52, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(landed ? endRotation : startRotation))
        .scaleEffect(absorbed ? 0.3 : 1.0)
        .opacity(absorbed ? 0 : 1)
        // Springy drop with a sideways start — reads as an arc into the tray
        .offset(x: landed ? 0 : startX, y: landed ? 0 : -215)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.74)) {
                landed = true
            }
            withAnimation(.easeIn(duration: 0.16).delay(0.4)) {
                absorbed = true
            }
        }
    }

    private var fallbackTile: some View {
        Rectangle()
            .fill(fallbackColor)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

// MARK: - SaveSuccessOverlay

private struct SaveSuccessOverlay: View {
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
        let symbols = ["photo.fill", "camera.fill", "sparkle",
                       "photo.fill", "sparkle", "camera.fill",
                       "photo.fill", "sparkle", "photo.fill", "sparkle"]
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
            // Light gradient backdrop — continuous with the saving screen underneath
            LinearGradient(
                colors: [Color(hex: 0xE4F2E8), Color(hex: 0xF7FBF8), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                }
            }

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.Colors.accent.opacity(0.45), radius: 24, x: 0, y: 8)
                    SaveCheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        .frame(width: 44, height: 44)
                }
                .scaleEffect(discScale)
                .opacity(discOpacity)

                VStack(spacing: 6) {
                    Text("Saved!")
                        .font(.custom("Caveat-Medium", size: 44))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("\(count) \(count == 1 ? "shot is" : "shots are") in your camera roll")
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

private struct SaveCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.40, y: rect.height * 0.82))
        p.addLine(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.20))
        return p
    }
}

#Preview {
    ReceivedReviewView(
        batch: ReceivedBatch(
            id: "preview", sessionId: "s1", sessionName: "Friday night",
            senderName: "Sara",
            rollingStartedAt: Date().addingTimeInterval(-3600),
            rollingStoppedAt: Date(),
            photos: (0..<9).map {
                ReceivedPhoto(id: "p\($0)", batchId: "preview", url: nil, captureDate: Date())
            }
        )
    ) { _ in }
}
