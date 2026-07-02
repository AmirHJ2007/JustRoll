import Foundation
import Photos
import Supabase

// MARK: - Row types (DB ↔ Swift)

private struct ProfileRow: Codable {
    let id: UUID
    let name: String
    let username: String
    let email: String
}

private struct SessionRow: Codable {
    let id: UUID
    let code: String
    let name: String
    let kind: String
    let status: String
    let creatorId: UUID
    let createdAt: Date
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, name, kind, status
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case endedAt   = "ended_at"
    }
}

private struct SessionMemberRow: Codable {
    let sessionId: UUID
    let userId: UUID
    let joinedAt: Date
    let leftAt: Date?
    let isRolling: Bool
    let rollingStartedAt: Date?
    let rollingStoppedAt: Date?
    let batchSent: Bool

    enum CodingKeys: String, CodingKey {
        case sessionId        = "session_id"
        case userId           = "user_id"
        case joinedAt         = "joined_at"
        case leftAt           = "left_at"
        case isRolling        = "is_rolling"
        case rollingStartedAt = "rolling_started_at"
        case rollingStoppedAt = "rolling_stopped_at"
        case batchSent        = "batch_sent"
    }

    // Graceful fallback: if batch_sent column doesn't exist yet (pre-migration),
    // default to false so the app still surfaces unsent batches.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId        = try c.decode(UUID.self,  forKey: .sessionId)
        userId           = try c.decode(UUID.self,  forKey: .userId)
        joinedAt         = try c.decode(Date.self,  forKey: .joinedAt)
        leftAt           = try c.decodeIfPresent(Date.self, forKey: .leftAt)
        isRolling        = (try? c.decode(Bool.self, forKey: .isRolling)) ?? false
        rollingStartedAt = try c.decodeIfPresent(Date.self, forKey: .rollingStartedAt)
        rollingStoppedAt = try c.decodeIfPresent(Date.self, forKey: .rollingStoppedAt)
        batchSent        = (try? c.decode(Bool.self, forKey: .batchSent)) ?? false
    }
}

private struct ContactRow: Codable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
    }
}

private struct PreferencesRow: Codable {
    let userId: UUID
    let nudgesEnabled: Bool
    let newPhotosEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userId            = "user_id"
        case nudgesEnabled     = "nudges_enabled"
        case newPhotosEnabled  = "new_photos_enabled"
    }
}

// MARK: - Insert payload types

private struct SessionInsert: Encodable {
    let code: String
    let name: String
    let kind: String
    let creatorId: String

    enum CodingKeys: String, CodingKey {
        case code, name, kind
        case creatorId = "creator_id"
    }
}

private struct MemberInsert: Encodable {
    let sessionId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId    = "user_id"
    }
}

private struct ContactInsert: Encodable {
    let requesterId: String
    let addresseeId: String

    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
    }
}

private struct PhotoInsert: Encodable {
    let id: String
    let sessionId: String
    let uploaderId: String
    let storagePath: String
    let captureDate: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId   = "session_id"
        case uploaderId  = "uploader_id"
        case storagePath = "storage_path"
        case captureDate = "capture_date"
    }
}

private struct DeliveryInsert: Encodable {
    let photoId: String
    let recipientId: String

    enum CodingKeys: String, CodingKey {
        case photoId     = "photo_id"
        case recipientId = "recipient_id"
    }
}

// MARK: - SupabaseService

final class SupabaseService: SupabaseServiceProtocol {

    static let shared = SupabaseService()

    private let client = SupabaseClient(
        supabaseURL: URL(string: SupabaseConfig.url)!,
        supabaseKey: SupabaseConfig.anonKey
    )

    var currentUser: User? = nil

    // MARK: Auth

    func restoreSession() async -> User? {
        guard let session = try? await client.auth.session else { return nil }
        let uid = session.user.id.uuidString
        guard let profile = try? await fetchProfileById(uid) else { return nil }
        let user = User(id: uid, email: session.user.email ?? profile.email,
                        name: profile.name, username: profile.username)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let session = try await client.auth.signIn(email: email, password: password)
        print("[SupabaseService] signIn auth OK — uid: \(session.user.id)")

        let uid = session.user.id.uuidString
        let profileRow: ProfileRow
        do {
            profileRow = try await fetchProfileById(uid)
        } catch {
            // Profile missing — create a placeholder from auth data
            print("[SupabaseService] signIn — no profile found, creating placeholder")
            let fallback = email.components(separatedBy: "@").first ?? "User"
            await insertProfile(id: uid, name: fallback, username: fallback, email: email)
            profileRow = ProfileRow(id: session.user.id, name: fallback, username: fallback, email: email)
        }

        let user = User(id: uid, email: session.user.email ?? email, name: profileRow.name, username: profileRow.username)
        currentUser = user
        return user
    }

    func signUp(name: String, username: String, email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["name": .string(name), "username": .string(username)]
        )
        let uid = response.user.id.uuidString
        print("[SupabaseService] signUp auth OK — uid: \(uid)")

        await insertProfile(id: uid, name: name, username: username, email: email)

        let user = User(id: uid, email: email, name: name, username: username)
        currentUser = user
        return user
    }

    // Tries RPC first (bypasses RLS), falls back to direct insert.
    private func insertProfile(id: String, name: String, username: String, email: String) async {
        struct CreateProfileParams: Encodable {
            let userId: String; let userName: String
            let userUsername: String; let userEmail: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"; case userName = "user_name"
                case userUsername = "user_username"; case userEmail = "user_email"
            }
        }
        struct ProfileInsert: Encodable {
            let id: String; let name: String; let username: String; let email: String
        }

        do {
            try await client
                .rpc("create_user_profile", params: CreateProfileParams(
                    userId: id, userName: name, userUsername: username, userEmail: email))
                .execute()
            print("[SupabaseService] insertProfile via RPC — OK")
            return
        } catch {
            print("[SupabaseService] insertProfile RPC failed: \(error)")
        }

        do {
            try await client
                .from("profiles")
                .upsert(ProfileInsert(id: id, name: name, username: username, email: email))
                .execute()
            print("[SupabaseService] insertProfile via direct upsert — OK")
        } catch {
            print("[SupabaseService] insertProfile direct upsert failed: \(error)")
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    // MARK: Sessions

    func fetchSessions() async throws -> [Session] {
        let uid = try currentUserId()

        // Sessions the current user is a member of
        let myMemberRows: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .eq("user_id", value: uid)
            .execute()
            .value

        guard !myMemberRows.isEmpty else { return [] }
        let sessionIds = myMemberRows.map { $0.sessionId.uuidString }

        let sessionRows: [SessionRow] = try await client
            .from("sessions")
            .select()
            .in("id", values: sessionIds)
            .execute()
            .value

        // All members for those sessions
        let allMemberRows: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .in("session_id", values: sessionIds)
            .execute()
            .value

        // Profiles for everyone in those sessions
        let userIds = Array(Set(allMemberRows.map { $0.userId.uuidString }))
        let profileRows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .in("id", values: userIds)
            .execute()
            .value

        let profileMap    = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id.uuidString, $0) })
        let membersBySession = Dictionary(grouping: allMemberRows, by: { $0.sessionId.uuidString })

        return sessionRows.compactMap { row -> Session? in
            guard let kind   = SessionKind(rawValue: row.kind),
                  let status = SessionStatus(rawValue: row.status) else { return nil }

            let members: [SessionMember] = (membersBySession[row.id.uuidString] ?? []).compactMap { m in
                guard let profile = profileMap[m.userId.uuidString] else { return nil }
                return SessionMember(
                    id: m.userId.uuidString,
                    name: profile.name,
                    joinedAt: m.joinedAt,
                    leftAt: m.leftAt,
                    isRolling: m.isRolling
                )
            }

            return Session(
                id: row.id.uuidString,
                code: row.code,
                name: row.name,
                members: members,
                status: status,
                createdAt: row.createdAt,
                kind: kind,
                creatorId: row.creatorId.uuidString
            )
        }
    }

    func createSession(name: String, kind: SessionKind, invitedContacts: [Contact] = []) async throws -> Session {
        let uid = try currentUserId()
        let code = randomCode()

        let inserted: SessionRow = try await client
            .from("sessions")
            .insert(SessionInsert(code: code, name: name, kind: kind.rawValue, creatorId: uid))
            .select()
            .single()
            .execute()
            .value

        let sid = inserted.id.uuidString
        let now = Date()

        // Insert creator
        try await client
            .from("session_members")
            .insert(MemberInsert(sessionId: sid, userId: uid))
            .execute()

        // Insert invited contacts
        for contact in invitedContacts {
            try? await client
                .from("session_members")
                .insert(MemberInsert(sessionId: sid, userId: contact.id))
                .execute()
        }

        let profile = try await fetchCurrentProfile()
        var members = [SessionMember(id: uid, name: profile.name, joinedAt: now)]
        members += invitedContacts.map { SessionMember(id: $0.id, name: $0.name, joinedAt: now) }

        return Session(
            id: sid,
            code: inserted.code,
            name: inserted.name,
            members: members,
            status: .pending,
            createdAt: inserted.createdAt,
            kind: kind,
            creatorId: uid
        )
    }

    func joinSession(code: String) async throws -> Session {
        let uid = try currentUserId()

        let sessionRows: [SessionRow] = try await client
            .from("sessions")
            .select()
            .eq("code", value: code.uppercased())
            .execute()
            .value

        guard let sessionRow = sessionRows.first else { throw ServiceError.sessionNotFound }

        try await client
            .from("session_members")
            .insert(MemberInsert(sessionId: sessionRow.id.uuidString, userId: uid))
            .execute()

        return try await fetchSessionById(sessionRow.id.uuidString)
    }

    func leaveSession(sessionId: String) async throws {
        let uid = try currentUserId()
        let now = ISO8601DateFormatter().string(from: Date())

        try await client
            .from("session_members")
            .update(["left_at": now])
            .eq("session_id", value: sessionId)
            .eq("user_id", value: uid)
            .execute()
    }

    func endSession(sessionId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        try await client
            .from("sessions")
            .update(["status": "ended", "ended_at": now])
            .eq("id", value: sessionId)
            .execute()

        try await client
            .from("session_members")
            .update(["left_at": now])
            .eq("session_id", value: sessionId)
            .is("left_at", value: nil)
            .execute()
    }

    func deleteSession(sessionId: String) async throws {
        try await client
            .from("sessions")
            .delete()
            .eq("id", value: sessionId)
            .execute()
    }

    func startRolling(sessionId: String) async throws {
        let uid = try currentUserId()
        let now = Date()
        struct StartRollingPayload: Encodable {
            let isRolling: Bool = true
            let leftAt: Date? = nil          // clear left_at so member is active again
            let rollingStartedAt: Date
            let rollingStoppedAt: Date? = nil // clear previous window
            let batchSent: Bool = false
            enum CodingKeys: String, CodingKey {
                case isRolling        = "is_rolling"
                case leftAt           = "left_at"
                case rollingStartedAt = "rolling_started_at"
                case rollingStoppedAt = "rolling_stopped_at"
                case batchSent        = "batch_sent"
            }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(isRolling, forKey: .isRolling)
                try c.encode(leftAt, forKey: .leftAt)
                try c.encode(rollingStartedAt, forKey: .rollingStartedAt)
                try c.encode(rollingStoppedAt, forKey: .rollingStoppedAt)
                try c.encode(batchSent, forKey: .batchSent)
            }
        }
        try await client
            .from("session_members")
            .update(StartRollingPayload(rollingStartedAt: now))
            .eq("session_id", value: sessionId)
            .eq("user_id", value: uid)
            .execute()

        try await client
            .from("sessions")
            .update(["status": "active"])
            .eq("id", value: sessionId)
            .execute()
    }

    func stopRolling(sessionId: String) async throws {
        let uid = try currentUserId()
        let now = Date()
        struct StopRollingPayload: Encodable {
            let isRolling: Bool = false
            let rollingStoppedAt: Date
            enum CodingKeys: String, CodingKey {
                case isRolling        = "is_rolling"
                case rollingStoppedAt = "rolling_stopped_at"
            }
        }
        try await client
            .from("session_members")
            .update(StopRollingPayload(rollingStoppedAt: now))
            .eq("session_id", value: sessionId)
            .eq("user_id", value: uid)
            .execute()

        // If no members are still rolling, set session back to pending
        let rollingMembers: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .eq("session_id", value: sessionId)
            .eq("is_rolling", value: true)
            .execute()
            .value

        if rollingMembers.isEmpty {
            try await client
                .from("sessions")
                .update(["status": "pending"])
                .eq("id", value: sessionId)
                .execute()
        }
    }

    // MARK: Contacts (disabled — re-enable with friend graph feature)

    /*
    func fetchContacts() async throws -> [Contact] {
        let uid = try currentUserId()

        let rows: [ContactRow] = try await client
            .from("contacts")
            .select()
            .or("requester_id.eq.\(uid),addressee_id.eq.\(uid)")
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let contactUserIds = rows.map { r -> String in
            r.requesterId.uuidString == uid ? r.addresseeId.uuidString : r.requesterId.uuidString
        }

        let profiles: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .in("id", values: contactUserIds)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.uuidString, $0) })

        return rows.compactMap { row -> Contact? in
            let contactUserId = row.requesterId.uuidString == uid
                ? row.addresseeId.uuidString
                : row.requesterId.uuidString
            guard let profile = profileMap[contactUserId] else { return nil }
            return Contact(
                id: row.id.uuidString,
                name: profile.name,
                username: profile.username,
                isConnected: row.status == "accepted",
                isPending: row.status == "pending",
                isIncoming: row.status == "pending" && row.addresseeId.uuidString == uid
            )
        }
    }

    func addContact(username: String) async throws -> Contact {
        let uid = try currentUserId()

        let profiles: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .ilike("username", value: username.lowercased())
            .execute()
            .value

        guard let target = profiles.first else { throw ServiceError.userNotFound }

        let inserted: ContactRow = try await client
            .from("contacts")
            .insert(ContactInsert(requesterId: uid, addresseeId: target.id.uuidString))
            .select()
            .single()
            .execute()
            .value

        return Contact(
            id: inserted.id.uuidString,
            name: target.name,
            username: target.username,
            isConnected: false,
            isPending: true,
            isIncoming: false
        )
    }

    func removeContact(contactId: String) async throws {
        try await client
            .from("contacts")
            .delete()
            .eq("id", value: contactId)
            .execute()
    }

    func acceptContact(contactId: String) async throws {
        try await client
            .from("contacts")
            .update(["status": "accepted"])
            .eq("id", value: contactId)
            .execute()
    }
    */

    // MARK: Profile & Preferences

    func fetchProfile() async throws -> User {
        let uid = try currentUserId()
        let profile = try await fetchProfileById(uid)
        return User(id: uid, email: profile.email, name: profile.name, username: profile.username)
    }

    func fetchPreferences() async throws -> (nudges: Bool, newPhotos: Bool) {
        let uid = try currentUserId()

        let rows: [PreferencesRow] = try await client
            .from("user_preferences")
            .select()
            .eq("user_id", value: uid)
            .execute()
            .value

        if let prefs = rows.first {
            return (nudges: prefs.nudgesEnabled, newPhotos: prefs.newPhotosEnabled)
        }
        return (nudges: true, newPhotos: true)
    }

    func updatePreferences(nudges: Bool, newPhotos: Bool) async throws {
        let uid = try currentUserId()

        struct PrefsUpsert: Encodable {
            let userId: String
            let nudgesEnabled: Bool
            let newPhotosEnabled: Bool
            enum CodingKeys: String, CodingKey {
                case userId           = "user_id"
                case nudgesEnabled    = "nudges_enabled"
                case newPhotosEnabled = "new_photos_enabled"
            }
        }

        try await client
            .from("user_preferences")
            .upsert(PrefsUpsert(userId: uid, nudgesEnabled: nudges, newPhotosEnabled: newPhotos))
            .execute()
    }

    // MARK: Photos

    func fetchPendingPhotos() async throws -> [PendingPhoto] { [] }

    func fetchPendingBatches() async throws -> [PendingBatch] {
        let uid = try currentUserId()

        // Query rolling windows for this user that haven't been sent yet
        let memberRows: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .eq("user_id", value: uid)
            .eq("batch_sent", value: false)
            .execute()
            .value

        let unsent = memberRows.filter { $0.rollingStoppedAt != nil && $0.rollingStartedAt != nil }
        guard !unsent.isEmpty else { return [] }

        // Require at least limited PhotoKit access to scan the camera roll
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else { return [] }

        // Fetch session details
        let sessionIds = unsent.map { $0.sessionId.uuidString }
        let sessionRows: [SessionRow] = try await client
            .from("sessions")
            .select()
            .in("id", values: sessionIds)
            .execute()
            .value

        // Fetch all members of those sessions to compute recipients
        let allMemberRows: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .in("session_id", values: sessionIds)
            .execute()
            .value

        var batches: [PendingBatch] = []

        for row in unsent {
            guard let start = row.rollingStartedAt, let stop = row.rollingStoppedAt else { continue }
            guard let sessionRow = sessionRows.first(where: { $0.id == row.sessionId }) else { continue }

            // Recipient names = other members in the session
            let otherIds = allMemberRows
                .filter { $0.sessionId == row.sessionId && $0.userId.uuidString != uid }
                .map { $0.userId.uuidString }

            var recipientNames: [String] = []
            if !otherIds.isEmpty {
                let profiles: [ProfileRow] = try await client
                    .from("profiles")
                    .select()
                    .in("id", values: otherIds)
                    .execute()
                    .value
                recipientNames = profiles.map(\.name)
            }

            // Fetch images and videos in the rolling window.
            // Screenshot check is done in Swift (not NSPredicate) so iOS's own
            // mediaSubtype.contains() logic is used — avoids SQLite bitwise edge cases
            // that can silently drop certain image subtypes (e.g. photos shot during video recording).
            let windowStart = start as NSDate
            let windowEnd   = stop  as NSDate

            let timePredicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                windowStart, windowEnd
            )
            let dateSortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)

            let imageOptions = PHFetchOptions()
            imageOptions.predicate = timePredicate
            imageOptions.sortDescriptors = [dateSortDescriptor]

            let videoOptions = PHFetchOptions()
            videoOptions.predicate = timePredicate
            videoOptions.sortDescriptors = [dateSortDescriptor]

            // Camera photos are HEIC ("public.heic") or JPEG ("public.jpeg").
            // Screenshots (old iOS: "com.apple.uikit.image", iOS 14+: "public.png")
            // and images saved/downloaded from other apps are PNG.
            // Excluding PNG-format assets reliably removes both without touching
            // camera-captured stills (including photos taken during video recording).
            let excludedUTIs: Set<String> = ["public.png", "com.apple.uikit.image"]
            var rawAssets: [(asset: PHAsset, isVideo: Bool)] = []
            let imageResult = PHAsset.fetchAssets(with: .image, options: imageOptions)
            for i in 0..<imageResult.count {
                let asset = imageResult.object(at: i)
                let resources = PHAssetResource.assetResources(for: asset)
                let isPNG = resources.contains { excludedUTIs.contains($0.uniformTypeIdentifier) }
                guard !isPNG else { continue }
                rawAssets.append((asset, false))
            }
            let videoResult = PHAsset.fetchAssets(with: .video, options: videoOptions)
            for i in 0..<videoResult.count {
                rawAssets.append((videoResult.object(at: i), true))
            }
            rawAssets.sort { ($0.asset.creationDate ?? start) < ($1.asset.creationDate ?? start) }

            let sessionLabel = sessionRow.name.isEmpty ? "Roll \(sessionRow.code)" : sessionRow.name
            var photos: [PendingPhoto] = rawAssets.map { entry in
                PendingPhoto(
                    id: entry.asset.localIdentifier,
                    sessionId: row.sessionId.uuidString,
                    sessionName: sessionLabel,
                    captureDate: entry.asset.creationDate ?? start,
                    isSelected: true,
                    isVideo: entry.isVideo,
                    asset: entry.asset
                )
            }

            batches.append(PendingBatch(
                id: row.sessionId.uuidString,
                sessionName: sessionLabel,
                photos: photos,
                rollingStartedAt: start,
                rollingStoppedAt: stop,
                recipientNames: recipientNames
            ))
        }

        return batches
    }

    func uploadPhotos(_ photos: [PendingPhoto], sessionId: String) async throws {
        let uid = try currentUserId()
        // Mark this rolling window as sent so it doesn't reappear
        try await client
            .from("session_members")
            .update(["batch_sent": true])
            .eq("session_id", value: sessionId)
            .eq("user_id", value: uid)
            .execute()

        // TODO: Upload photos to Supabase Storage + insert photo_deliveries rows
        // For each PendingPhoto:
        //   1. Load UIImage via PHImageManager (photo.asset)
        //   2. Compress to JPEG
        //   3. Upload to "photos/{sessionId}/{photoId}.jpg"
        //   4. INSERT into photos table
        //   5. INSERT photo_deliveries rows for each recipient
    }

    // MARK: Private helpers

    private func currentUserId() throws -> String {
        guard let uid = currentUser?.id else { throw ServiceError.unauthorized }
        return uid
    }

    private func fetchProfileById(_ id: String) async throws -> ProfileRow {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        guard let profile = rows.first else { throw ServiceError.userNotFound }
        return profile
    }

    private func fetchCurrentProfile() async throws -> ProfileRow {
        try await fetchProfileById(try currentUserId())
    }

    private func fetchSessionById(_ id: String) async throws -> Session {
        let sessionRows: [SessionRow] = try await client
            .from("sessions")
            .select()
            .eq("id", value: id)
            .execute()
            .value

        guard let row = sessionRows.first,
              let kind   = SessionKind(rawValue: row.kind),
              let status = SessionStatus(rawValue: row.status) else {
            throw ServiceError.sessionNotFound
        }

        let memberRows: [SessionMemberRow] = try await client
            .from("session_members")
            .select()
            .eq("session_id", value: id)
            .execute()
            .value

        let userIds = memberRows.map { $0.userId.uuidString }
        let profiles: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .in("id", values: userIds)
            .execute()
            .value
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.uuidString, $0) })

        let members: [SessionMember] = memberRows.compactMap { m in
            guard let profile = profileMap[m.userId.uuidString] else { return nil }
            return SessionMember(id: m.userId.uuidString, name: profile.name,
                                 joinedAt: m.joinedAt, leftAt: m.leftAt, isRolling: m.isRolling)
        }

        return Session(id: row.id.uuidString, code: row.code, name: row.name,
                       members: members, status: status, createdAt: row.createdAt, kind: kind)
    }

    private func randomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).compactMap { _ in chars.randomElement() })
    }
}
