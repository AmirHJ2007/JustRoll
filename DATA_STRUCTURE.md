# JustRoll — Data Structure

## Overview

Data is split across three layers:

| Layer | What lives here |
|---|---|
| **Supabase Auth** | Identity — email, password, raw user metadata |
| **Supabase Database** | All relational data — profiles, sessions, contacts, photos |
| **Supabase Storage** | Photo files (bucket: `photos`) |
| **iOS (Swift)** | View-layer models assembled from DB rows |

---

## Database Tables

### `profiles`
One row per user. Created automatically on sign-up via the `on_auth_user_created` trigger (and also by the Swift SDK as a fallback).

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | Mirrors `auth.users.id` |
| `name` | TEXT | Display name |
| `username` | TEXT (unique) | Used for friend search |
| `email` | TEXT | |
| `created_at` | TIMESTAMPTZ | Auto-set |

---

### `sessions`
A roll/hangout. One row per session.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `code` | VARCHAR(5) (unique) | Short invite code, e.g. `4F9K2` |
| `name` | TEXT | User-given name |
| `kind` | ENUM | `disposable` or `lasting` |
| `status` | ENUM | `pending` → `active` → `ended` |
| `creator_id` | UUID → profiles | Who started the roll |
| `created_at` | TIMESTAMPTZ | |
| `ended_at` | TIMESTAMPTZ | Null while session is open |

---

### `session_members`
Composite PK: `(session_id, user_id)`. One row per person per session.
The join/leave timestamps are the core of the who-gets-what rule.

| Column | Type | Notes |
|---|---|---|
| `session_id` | UUID → sessions | |
| `user_id` | UUID → profiles | |
| `joined_at` | TIMESTAMPTZ | When they tapped in |
| `left_at` | TIMESTAMPTZ | Null while still in session |
| `is_rolling` | BOOLEAN | Whether they are actively capturing right now |

**Who-gets-what rule:** A photo goes to every member whose `joined_at ≤ photo.capture_date` and (`left_at` is null OR `left_at ≥ photo.capture_date`).

---

### `contacts`
Mutual friendship model. One row per pair.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `requester_id` | UUID → profiles | Who sent the request |
| `addressee_id` | UUID → profiles | Who received it |
| `status` | ENUM | `pending` → `accepted` or `rejected` |
| `created_at` | TIMESTAMPTZ | |

Constraints: `requester_id != addressee_id`, unique pair `(requester_id, addressee_id)`.

---

### `photos`
One row per uploaded photo. The file lives in Storage; this row is the metadata.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `session_id` | UUID → sessions | |
| `uploader_id` | UUID → profiles | Who took it |
| `storage_path` | TEXT | Path in Storage bucket, e.g. `{session_id}/{photo_id}.jpg` |
| `capture_date` | TIMESTAMPTZ | From EXIF metadata (not upload time) |
| `uploaded_at` | TIMESTAMPTZ | |

---

### `photo_deliveries`
Per-recipient delivery tracking. Composite PK: `(photo_id, recipient_id)`.

| Column | Type | Notes |
|---|---|---|
| `photo_id` | UUID → photos | |
| `recipient_id` | UUID → profiles | |
| `delivered_at` | TIMESTAMPTZ | Null = not yet saved to camera roll |

---

### `user_preferences`
One row per user. Created on first preference save.

| Column | Type | Notes |
|---|---|---|
| `user_id` | UUID (PK) → profiles | |
| `nudges_enabled` | BOOLEAN | "Still hanging out?" push |
| `new_photos_enabled` | BOOLEAN | "Photos arrived" push |
| `updated_at` | TIMESTAMPTZ | |

---

### `device_tokens`
One row per device that registered for push. Read by the `send-push` Edge Function (service role) to deliver APNs notifications.

| Column | Type | Notes |
|---|---|---|
| `token` | TEXT (PK) | Hex-encoded APNs device token |
| `user_id` | UUID → profiles | Owner; cascades on account delete |
| `updated_at` | TIMESTAMPTZ | Refreshed on each app launch |

---

## Enum Types

```sql
session_kind:   disposable | lasting
session_status: pending | active | ended
contact_status: pending | accepted | rejected
```

---

## Storage

- **Bucket:** `photos` (private)
- **Path convention:** `{session_id}/{photo_id}.jpg`
- Access is authenticated only — no public URLs

---

## Swift Models (iOS layer)

These are assembled from DB rows in `SupabaseService` — they are not stored directly in the database.

### `User`
```swift
struct User: Identifiable {
    let id: String        // profiles.id
    let email: String
    let name: String
    let username: String
}
```

### `Contact`
```swift
struct Contact: Identifiable {
    let id: String        // contacts.id
    let name: String
    let username: String
    var isConnected: Bool // true = accepted, false = pending
}
```

### `Session`
```swift
struct Session: Identifiable {
    let id: String
    let code: String
    var name: String
    var members: [SessionMember]
    var status: SessionStatus   // pending | active | ended
    let createdAt: Date
    var kind: SessionKind       // disposable | lasting
}
```

### `SessionMember`
```swift
struct SessionMember: Identifiable {
    let id: String        // profiles.id
    let name: String
    let joinedAt: Date
    var leftAt: Date?
    var isActive: Bool    // leftAt == nil
}
```

### `PendingBatch` *(view-layer only — not a DB table)*
Assembled after a session ends, from the user's photo library filtered by the session window. Lives only in memory until the user reviews and sends.

```swift
struct PendingBatch: Identifiable {
    let id: String            // == sessionId
    let sessionName: String
    var photos: [PendingPhoto]
    let sessionStarted: Date
    let sessionEnded: Date
    let recipientNames: [String]
    var expiresAt: Date       // sessionEnded + 7 days
}
```

### `PendingPhoto` *(view-layer only)*
One entry per photo in a pending batch. Not stored in DB until the user approves and uploads.

```swift
struct PendingPhoto: Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let captureDate: Date   // from PHAsset EXIF, not library-add time
    var isSelected: Bool    // user can deselect before sending
    // TODO: add PHAsset reference for actual image upload
}
```

---

## Row Level Security Summary

| Table | Read | Insert | Update | Delete |
|---|---|---|---|---|
| `profiles` | Any authenticated user | Own row only | Own row only | — |
| `sessions` | Members only | Authenticated (creator) | Creator only | Creator only |
| `session_members` | Co-members | Self only | Self only | Self only |
| `contacts` | Either party | Requester only | Addressee only | Either party |
| `photos` | Session members | Session members (uploader) | — | — |
| `photo_deliveries` | Recipient only | Uploader only | Recipient only | — |
| `user_preferences` | Own row | Own row | Own row | Own row |

---

## Key Flows

### Sign-up
1. `auth.signUp(email, password, data: {name, username})` → creates `auth.users` row
2. Swift SDK calls `create_user_profile` RPC (SECURITY DEFINER, bypasses RLS) → inserts `profiles` row
3. DB trigger `on_auth_user_created` runs as backup (same insert, `ON CONFLICT DO NOTHING`)

### Start a roll
1. INSERT `sessions` (code, name, kind, creator_id)
2. INSERT `session_members` (session_id, user_id, joined_at)

### Join a roll
1. Fetch `sessions` by `code`
2. INSERT `session_members` for current user

### End a roll → collect photos
1. UPDATE `session_members.left_at = now()` for current user
2. UPDATE `sessions.status = 'ended'` (if creator or disposable)
3. App reads `PHPhotoLibrary`, filters by `joined_at ≤ capture_date ≤ left_at`
4. User reviews and deselects on the Unsent screen
5. For each approved photo: upload file to Storage, INSERT `photos`, INSERT `photo_deliveries` for each recipient computed from `session_members` timestamps

### Deliver photos
1. Recipient opens app (or silent push wakes it)
2. Query `photo_deliveries WHERE recipient_id = me AND delivered_at IS NULL`
3. Download files from Storage, save to camera roll
4. UPDATE `photo_deliveries.delivered_at = now()`
