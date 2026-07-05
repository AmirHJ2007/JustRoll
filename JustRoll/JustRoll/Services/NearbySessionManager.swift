import MultipeerConnectivity
import Observation
import SwiftUI
import UIKit

struct JoinInvitePayload {
    let sessionCode: String
    let sessionName: String
    let fromDisplayName: String
}

@Observable
@MainActor
final class NearbySessionManager: NSObject {
    static let shared = NearbySessionManager()

    private let serviceType = "justroll-join"

    private var peerId: MCPeerID?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var dataSession: MCSession?

    var discoveredPeople: [NearbyPerson] = []
    var isScanning = false
    var pendingJoinInvite: JoinInvitePayload?

    // MARK: - Public API

    /// Start advertising only (call when app opens so others can discover this device
    /// even when the radar view is not open).
    func startAdvertising(displayName: String, username: String, avatarId: Int? = nil) {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil

        let pid = MCPeerID(displayName: displayName)
        peerId = pid

        var info = ["username": username]
        if let avatarId { info["avatar"] = String(avatarId) }
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    /// Start both advertising and browsing (call when radar view appears).
    func start(displayName: String, username: String, avatarId: Int? = nil) {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        discoveredPeople = []

        let pid = MCPeerID(displayName: displayName)
        peerId = pid

        var info = ["username": username]
        if let avatarId { info["avatar"] = String(avatarId) }
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let brow = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        brow.delegate = self
        brow.startBrowsingForPeers()
        browser = brow

        isScanning = true
    }

    /// Stop only browsing; keeps advertising so others can still discover this device.
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredPeople = []
        isScanning = false
    }

    /// Stop everything (call when logging out).
    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        peerId = nil
        discoveredPeople = []
        isScanning = false
    }

    /// Send a session join invite to selected nearby peers via MPC invitation context.
    /// The session code travels in the invitation's context Data — no full MPC connection needed.
    func sendJoinInvite(sessionCode: String, sessionName: String, to people: [NearbyPerson]) {
        guard let pid = peerId, let brow = browser else { return }

        let payload: [String: String] = ["code": sessionCode, "name": sessionName]
        guard let context = try? JSONSerialization.data(withJSONObject: payload) else { return }

        // Create a throw-away MCSession just as the vehicle for the invite.
        let session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        dataSession = session

        for person in people {
            brow.invitePeer(person.peerId, to: session, withContext: context, timeout: 15)
        }
    }

    private func makeNearbyPerson(name: String, username: String, avatarId: Int?, peerId: MCPeerID) -> NearbyPerson {
        let seed = abs(peerId.hashValue)
        let angle = Double(seed % 360)
        let distance = 0.28 + (CGFloat(seed / 360 % 55) / 100.0)
        return NearbyPerson(name: name, username: username, avatarId: avatarId, distance: distance, angle: angle, discoveryDelay: 0, peerId: peerId)
    }
}

// MARK: - MCSessionDelegate (minimal — only used as vehicle for invite context)

extension NearbySessionManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbySessionManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Check whether the invitation carries a JustRoll join payload.
        if let context,
           let payload = try? JSONSerialization.jsonObject(with: context) as? [String: String],
           let code = payload["code"],
           let name = payload["name"] {
            Task { @MainActor in
                self.pendingJoinInvite = JoinInvitePayload(
                    sessionCode: code,
                    sessionName: name,
                    fromDisplayName: peerID.displayName
                )
            }
        }
        // Always decline the MCSession connection itself — the context data is all we need.
        invitationHandler(false, nil)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: Error) {
        print("[NearbySessionManager] advertiser error: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbySessionManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let displayName = peerID.displayName
        let username = info?["username"] ?? displayName
        let avatarId = info?["avatar"].flatMap(Int.init)
        let copy = peerID
        Task { @MainActor in
            guard !self.discoveredPeople.contains(where: { $0.name == displayName }) else { return }
            let person = self.makeNearbyPerson(name: displayName, username: username, avatarId: avatarId, peerId: copy)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.discoveredPeople.append(person)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             lostPeer peerID: MCPeerID) {
        let displayName = peerID.displayName
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                self.discoveredPeople.removeAll { $0.name == displayName }
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        print("[NearbySessionManager] browser error: \(error)")
    }
}
