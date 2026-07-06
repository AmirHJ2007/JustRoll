import Foundation

/// A completed rolling window, persisted locally so multiple unsent rolls
/// per circle each keep their own card. The server only remembers the
/// latest window; this store remembers them all until sent or expired.
struct CompletedRoll: Codable, Identifiable, Equatable {
    let sessionId: String
    let startedAt: Date
    let stoppedAt: Date
    var id: String { "\(sessionId)_\(Int(startedAt.timeIntervalSince1970))" }
}

enum RollStore {
    private static let key = "completedRolls"
    /// Serializes all read-modify-write cycles below — `add`/`remove`/`all`'s
    /// prune-write can otherwise race when called concurrently (e.g. from
    /// RootTabView's launch .task and a tab's own .task at once).
    private static let lock = NSLock()

    /// All locally-remembered rolls, pruned of anything past its 7-day expiry
    /// window (matches PendingBatch.expiresAt). Pruning is persisted back.
    static func all() -> [CompletedRoll] {
        lock.lock()
        defer { lock.unlock() }
        return allLocked()
    }

    /// No-op if an entry with the same id already exists.
    static func add(_ roll: CompletedRoll) {
        lock.lock()
        defer { lock.unlock() }
        var rolls = allLocked()
        guard !rolls.contains(where: { $0.id == roll.id }) else { return }
        rolls.append(roll)
        save(rolls)
    }

    static func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        var rolls = allLocked()
        rolls.removeAll { $0.id == id }
        save(rolls)
    }

    /// Must only be called while `lock` is held.
    private static func allLocked() -> [CompletedRoll] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CompletedRoll].self, from: data) else {
            return []
        }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let pruned = decoded.filter { $0.stoppedAt > cutoff }

        if pruned.count != decoded.count {
            save(pruned)
        }

        return pruned
    }

    private static func save(_ rolls: [CompletedRoll]) {
        guard let data = try? JSONEncoder().encode(rolls) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
