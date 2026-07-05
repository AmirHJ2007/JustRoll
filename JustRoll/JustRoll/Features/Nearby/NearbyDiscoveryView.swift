import MultipeerConnectivity
import SwiftUI

// MARK: - Model

struct NearbyPerson: Identifiable {
    let id: UUID
    let name: String
    /// Supabase username — used to add the person to a session via the backend.
    let username: String
    /// Picked preset avatar (1–12) — travels in MPC discovery info.
    let avatarId: Int?
    /// 0.25–0.82 fraction of radar radius (closer = inner ring)
    let distance: CGFloat
    /// Degrees, 0 = right, clockwise
    let angle: Double
    /// Seconds after radar starts before this person appears (kept for API compat)
    let discoveryDelay: Double
    /// The underlying MPC peer — needed to send a notification invite.
    let peerId: MCPeerID

    init(name: String, username: String, avatarId: Int? = nil, distance: CGFloat, angle: Double, discoveryDelay: Double, peerId: MCPeerID) {
        self.id = UUID()
        self.name = name; self.username = username; self.avatarId = avatarId
        self.distance = distance
        self.angle = angle; self.discoveryDelay = discoveryDelay
        self.peerId = peerId
    }
}

// MARK: - Radar Canvas

// Sonar pulse rings only — lives in a Canvas that fills the ENTIRE available area
// so rings can expand past the radar boundary to the screen edges.
struct SonarPulseView: View {
    /// Radar center in this view's local coordinate space (= the geo area origin).
    let center: CGPoint
    /// Radar circle radius (used for the static-rings fallback only).
    let radarRadius: CGFloat
    /// Distance from radar center to the farthest screen corner.
    let fullRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pulseCount  = 3
    private let pulsePeriod = 8.0   // seconds for one ring to travel from center to screen edge
    private let ringCount   = 4     // static-rings fallback count

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            Canvas { ctx, _ in
                let t = tl.date.timeIntervalSinceReferenceDate
                if reduceMotion {
                    drawStaticRings(&ctx)
                } else {
                    drawPulse(&ctx, t)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func drawStaticRings(_ ctx: inout GraphicsContext) {
        for i in 1...ringCount {
            let r     = radarRadius * CGFloat(i) / CGFloat(ringCount)
            let alpha = 0.06 + 0.05 * CGFloat(i) / CGFloat(ringCount)
            var p = Path()
            p.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
            ctx.stroke(p, with: .color(Theme.Colors.accent.opacity(alpha)), lineWidth: 1)
        }
    }

    // Rings born at center, expand with gentle ease-out to fullRadius, fade out at the edge.
    private func drawPulse(_ ctx: inout GraphicsContext, _ t: Double) {
        let base = t.truncatingRemainder(dividingBy: pulsePeriod) / pulsePeriod

        for i in 0..<pulseCount {
            let phase = (base + Double(i) / Double(pulseCount)).truncatingRemainder(dividingBy: 1.0)

            // Very gentle ease-out (exponent 1.3): rings "ooze" outward slowly,
            // decelerating only a little near the screen edge — much calmer than 2.2.
            let eased = 1.0 - pow(1.0 - phase, 1.3)
            let r     = fullRadius * CGFloat(eased)

            // Fade in over first 8% of life, then concave fade-out so rings stay
            // clearly visible well past the radar and vanish at the screen edge.
            let fadeIn = min(phase / 0.08, 1.0)
            let alpha  = CGFloat(fadeIn) * pow(1.0 - phase, 0.40) * 0.34
            let lw     = max(CGFloat(1.6 - phase * 0.8), 0.4)

            guard alpha > 0.006 else { continue }

            var p = Path()
            p.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
            ctx.stroke(p, with: .color(Theme.Colors.accent.opacity(alpha)), lineWidth: lw)
        }
    }
}

// Sweep arc + static rings (bounded to radar area, sits on top of the sonar pulse)
struct RadarCanvasView: View {
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trailAngle  = Double.pi / 3
    private let sweepPeriod = 4.0
    private let steps       = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let t = tl.date.timeIntervalSinceReferenceDate
                let sweep = reduceMotion ? 0.0
                    : (t.truncatingRemainder(dividingBy: sweepPeriod) / sweepPeriod) * .pi * 2
                if !reduceMotion { drawSweep(&ctx, c, sweep) }
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func drawSweep(_ ctx: inout GraphicsContext, _ c: CGPoint, _ angle: Double) {
        for i in 0..<steps {
            let t  = Double(i) / Double(steps)
            let a0 = angle - trailAngle + t * trailAngle
            let a1 = angle - trailAngle + (t + 1.0 / Double(steps)) * trailAngle
            var p  = Path()
            p.move(to: c)
            p.addArc(center: c, radius: radius * 0.97,
                     startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            p.closeSubpath()
            ctx.fill(p, with: .color(Theme.Colors.accent.opacity(t * 0.36)))
        }
        var spoke = Path()
        spoke.move(to: c)
        spoke.addLine(to: CGPoint(x: c.x + cos(angle) * radius * 0.97,
                                   y: c.y + sin(angle) * radius * 0.97))
        ctx.stroke(spoke, with: .color(Theme.Colors.accent.opacity(0.65)), lineWidth: 1.5)
    }
}

// MARK: - Center Avatar (my own, with pulsing ring)

private struct CenterAvatarView: View {
    let name: String
    var avatarId: Int? = nil
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Theme.Colors.accent.opacity(0.22), lineWidth: 2)
                .frame(width: 84, height: 84)
                .scaleEffect(pulsing ? 1.35 : 1)
                .opacity(pulsing ? 0 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                        pulsing = true
                    }
                }

            // Olive accent ring
            Circle()
                .stroke(Theme.Colors.accent, lineWidth: 2.5)
                .frame(width: 62, height: 62)

            // Tinted fill circle
            Circle()
                .fill(Theme.Colors.accentTint)
                .frame(width: 56, height: 56)

            AvatarView(name: name, size: 48, avatarId: avatarId)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
        }
        .shadow(color: Theme.Colors.accent.opacity(0.22), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Nearby Avatar Node

struct NearbyAvatarNode: View {
    let person: NearbyPerson
    let isSelected: Bool
    let onTap: () -> Void

    @State private var revealed = false
    @State private var bopping  = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Stable pseudo-random values derived from person id so they survive re-renders
    private var bobAmp:      CGFloat { CGFloat(abs(person.id.hashValue) % 5 + 3) }
    private var bobDuration: Double  { 1.9 + Double(abs(person.id.hashValue / 13) % 10) / 10.0 }
    private var bobDelay:    Double  { Double(abs(person.id.hashValue / 7) % 15) / 10.0 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    // Olive selection halo
                    Circle()
                        .stroke(Theme.Colors.accent, lineWidth: 2.5)
                        .frame(width: 60, height: 60)
                        .scaleEffect(isSelected ? 1.14 : 0.75)
                        .opacity(isSelected ? 1 : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isSelected)

                    AvatarView(name: person.name, size: 44, avatarId: person.avatarId)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                        .scaleEffect(isSelected ? 1.08 : 1)
                        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isSelected)
                }

                Text(person.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
        // Develop-in entrance (blur + scale + opacity from nothing)
        .scaleEffect(revealed ? 1 : 0.18)
        .blur(radius: revealed ? 0 : 14)
        .opacity(revealed ? 1 : 0)
        // Idle bob
        .offset(y: bopping ? bobAmp : -bobAmp)
        .onAppear {
            withAnimation(
                reduceMotion ? .easeIn(duration: 0.3)
                             : .spring(response: 0.65, dampingFraction: 0.60)
            ) { revealed = true }

            guard !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75 + bobDelay) {
                withAnimation(.easeInOut(duration: bobDuration).repeatForever(autoreverses: true)) {
                    bopping = true
                }
            }
        }
    }
}

// MARK: - Main screen

enum NearbyMode {
    case startRoll
    case addFriend
}

struct NearbyDiscoveryView: View {
    var mode: NearbyMode = .startRoll
    var currentUserName: String = "Me"
    var currentUserUsername: String = ""
    var currentUserAvatarId: Int? = nil
    /// When set, tapping "Start a roll" sends this code to selected peers via MPC.
    var sessionCode: String? = nil
    var sessionDisplayName: String? = nil
    /// Called with the confirmed selection just before the view dismisses.
    var onConfirm: (([NearbyPerson]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Names of tapped peers (stable key even if UUID changes on re-discovery)
    @State private var selectedNames: Set<String> = []
    @State private var pillScale: CGFloat = 1

    private var discovered: [NearbyPerson] { NearbySessionManager.shared.discoveredPeople }
    private var selectedPeople: [NearbyPerson] { discovered.filter { selectedNames.contains($0.name) } }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                GeometryReader { geo in radarLayer(geo) }
            }

            if !selectedNames.isEmpty {
                VStack {
                    Spacer()
                    startRollBar(selectedPeople)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: selectedNames.isEmpty)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            NearbySessionManager.shared.start(
                displayName: currentUserName,
                username: currentUserUsername,
                avatarId: currentUserAvatarId
            )
        }
        .onDisappear {
            // Keep advertising so others can still discover this device; only stop browsing.
            NearbySessionManager.shared.stopBrowsing()
        }
        .onChange(of: discovered.count) { _, newCount in
            // Bounce the counter pill when someone new appears
            withAnimation(.spring(response: 0.20, dampingFraction: 0.35)) { pillScale = 1.25 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) { pillScale = 1.0 }
            }
            // Remove selected names that are no longer present
            let currentNames = Set(discovered.map(\.name))
            selectedNames = selectedNames.intersection(currentNames)
        }
    }

    // MARK: Header panel

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Who's around?")
                        .font(Theme.Typography.displayTitle)
                        .foregroundColor(Theme.Colors.textPrimary)
                    SwooshUnderline().frame(height: 8)
                }
                // Live counter pill — bounces when count changes
                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 4, height: 4)
                        Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 4, height: 4)
                    }
                    Group {
                        if discovered.count == 0 {
                            Text("Looking for friends nearby…")
                        } else {
                            Text("\(discovered.count) \(discovered.count == 1 ? "friend" : "friends") nearby")
                        }
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: discovered.count)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.Colors.accentTint)
                .clipShape(Capsule())
                .scaleEffect(pillScale)
            }

            Spacer(minLength: 8)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
            .fill(Theme.Colors.background)
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
            .ignoresSafeArea(edges: .top)
        }
        .zIndex(1)
    }

    // MARK: Radar layer

    @ViewBuilder
    private func radarLayer(_ geo: GeometryProxy) -> some View {
        let side    = min(geo.size.width, geo.size.height)
        let radar   = side * 0.40
        let cx      = geo.size.width / 2
        let cy      = geo.size.height * 0.44
        let center  = CGPoint(x: cx, y: cy)
        // Farthest screen-corner distance from radar center
        let fullR   = max(
            hypot(cx,                    cy),
            hypot(geo.size.width - cx,   cy),
            hypot(cx,                    geo.size.height - cy),
            hypot(geo.size.width - cx,   geo.size.height - cy)
        )

        ZStack {
            // Sonar pulse — fills the full geo area so rings expand to screen edges unclipped
            SonarPulseView(center: center, radarRadius: radar, fullRadius: fullR)

            // Sweep arc — bounded to radar circle, sits on top of pulse rings
            RadarCanvasView(radius: radar)
                .position(x: cx, y: cy)

            // My avatar dead-center
            CenterAvatarView(name: currentUserName, avatarId: currentUserAvatarId)
                .position(x: cx, y: cy)

            // Discovered friends at their angular positions
            ForEach(discovered) { person in
                let rad = person.angle * .pi / 180
                let d   = radar * person.distance
                NearbyAvatarNode(
                    person: person,
                    isSelected: selectedNames.contains(person.name),
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            if selectedNames.contains(person.name) {
                                selectedNames.remove(person.name)
                            } else {
                                selectedNames.insert(person.name)
                            }
                        }
                    }
                )
                .position(x: cx + cos(rad) * d, y: cy + sin(rad) * d)
            }

            // Empty-state hint — fades away once first friend appears
            if discovered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Theme.Colors.accent.opacity(0.40))
                    Text("Make sure your friends\nhave JustRoll open")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .position(x: cx, y: cy + radar + 56)
                .transition(.opacity.animation(.easeOut(duration: 0.4)))
            }
        }
    }

    // MARK: "Start a roll" action bar

    private func startRollBar(_ people: [NearbyPerson]) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.Colors.border)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            // Selected avatars strip
            HStack(spacing: -10) {
                ForEach(people) { person in
                    AvatarView(name: person.name, size: 36, avatarId: person.avatarId)
                        .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 2.5))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: people.map(\.id))
            .padding(.top, 14)

            Button {
                if let code = sessionCode, let name = sessionDisplayName {
                    NearbySessionManager.shared.sendJoinInvite(
                        sessionCode: code,
                        sessionName: name,
                        to: people
                    )
                }
                onConfirm?(people)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: mode == .addFriend ? "person.badge.plus" : "film.stack.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(rollLabel(for: people))
                        .font(Theme.Typography.label)
                        .contentTransition(.interpolate)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
                .shadow(color: Theme.Colors.accent.opacity(0.28), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.background)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 22
            )
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: -5)
    }

    private func rollLabel(for people: [NearbyPerson]) -> String {
        switch mode {
        case .startRoll:
            switch people.count {
            case 0: return ""
            case 1: return "Start a roll with \(people[0].name)"
            case 2: return "Start a roll with \(people[0].name) & \(people[1].name)"
            default: return "Start a roll with \(people.count) people"
            }
        case .addFriend:
            switch people.count {
            case 0: return ""
            case 1: return "Add \(people[0].name) to your friends"
            case 2: return "Add \(people[0].name) & \(people[1].name)"
            default: return "Add \(people.count) people to your friends"
            }
        }
    }
}

#Preview {
    NearbyDiscoveryView(currentUserName: "Amir", currentUserUsername: "amir")
}
