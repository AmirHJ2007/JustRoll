import Foundation

enum SessionStatus: String, Equatable, Codable {
    case pending  // joined, not yet rolling
    case active   // rolling now
    case ended    // session window closed
}

enum SessionKind: String, Equatable, Codable {
    case disposable
    case lasting
}

struct SessionMember: Identifiable, Equatable {
    let id: String
    let name: String
    var avatarId: Int? = nil
    let joinedAt: Date
    var leftAt: Date?
    var isRolling: Bool = false
    var rollingStartedAt: Date? = nil
    var rollingStoppedAt: Date? = nil

    var isActive: Bool { leftAt == nil }
}

struct Session: Identifiable {
    let id: String
    let code: String
    var name: String
    var members: [SessionMember]
    var status: SessionStatus
    let createdAt: Date
    var kind: SessionKind
    var creatorId: String = ""

    var displayName: String {
        name.isEmpty ? "Roll \(code)" : name
    }

    var activeMembers: [SessionMember] {
        members.filter(\.isActive)
    }

    // Returns members who were active at a given capture time — used for who-gets-what tagging.
    func recipients(at captureDate: Date) -> [SessionMember] {
        members.filter { member in
            member.joinedAt <= captureDate &&
            (member.leftAt == nil || member.leftAt! >= captureDate)
        }
    }
}
