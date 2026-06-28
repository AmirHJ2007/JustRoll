import Foundation

enum SessionStatus: Equatable {
    case active
    case ended
}

struct SessionMember: Identifiable, Equatable {
    let id: String
    let name: String
    let joinedAt: Date
    var leftAt: Date?

    var isActive: Bool { leftAt == nil }
}

struct Session: Identifiable {
    let id: String
    let code: String
    var name: String
    var members: [SessionMember]
    var status: SessionStatus
    let createdAt: Date

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
