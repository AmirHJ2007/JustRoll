# CLAUDE.md — JustRoll

> Context file for building JustRoll. Read this before working on the app.

## What it is

JustRoll is an iOS app that automatically shares the photos you take while
hanging out with the friends who were physically there with you. No group
chats, no manual sending, no "I'll send them later." The photos land straight
in everyone's camera roll.

One-liner: **Hang out, everyone taps in, and the photos find their way to the
people who were there.**

## The problem it solves

When friends hang out, one person takes most of the photos and the rest never
get them — they sit on one phone, or get half-shared to a group chat. JustRoll
makes the sharing automatic and effortless, and — crucially — it knows *who you
were actually with* without you having to pick anyone.

## How it works (the model)

This is the core flow. It was arrived at by working around iOS constraints (see
"Constraints" below), so don't "simplify" it back into something Apple won't
allow.

1. **Start / join a session.** At the start of a hangout, everyone opens the app
   and joins the same session. Joining is via a short **room code** (one person
   starts a roll, gets a code like `4F9K2`, others type it in). This is the one
   moment we can rely on everyone's app being open — so we do the group-matching
   here, once.
2. **Everyone uses their normal camera all night.** The app does NOT need its own
   camera and does NOT monitor the camera in the background. People shoot with
   the stock Camera app like always.
3. **Join + leave timestamps define the window.** The app records when each
   person joined and when they left/ended the session.
4. **On leave/end, collect photos by timestamp.** When a user ends their session
   (app is open at that moment), the app reads the photo library and selects
   every photo whose **capture time** (from photo metadata, not added-to-library
   time) falls within their session window.
5. **Review-and-deselect screen (REQUIRED).** Before anything sends, show the
   user a grid of the photos from that window and let them deselect anything
   private. This is a hard requirement — without it we will eventually broadcast
   someone's private photo (a receipt, a screenshot, a document) to a group.
   This screen is the privacy safety net. Do not auto-send silently.
6. **Upload to Supabase, tagged per recipient.** Selected photos upload to the
   backend, tagged for the friends who were in the session *at the moment each
   photo was taken*.
7. **Deliver on next open (or via silent push).** Recipients get the photos the
   next time they open the app (today, next week, whenever). Photos save to their
   real camera roll. A push notification can wake the app to download.

### Who-gets-what rule

A photo goes to whoever was active in the session at that photo's capture time.
Late joiners only get photos taken after they joined. This is fully computable
from join/leave timestamps.

## Session lifecycle details

- **Joining:** room code (primary). QR code can be added later as a nicer option.
  Do NOT start with Bluetooth auto-discovery — most work, least reliability.
- **Ending:** user taps off. There is also an auto-off safety net:
  - A **nudge** push every ~3–4 hours: "Still hanging out? Keep sharing or turn
    off."
  - An **auto-off timer** as the real guarantee (the nudge can be missed if the
    user is asleep / phone in bag). If no response within a window (~20–30 min)
    OR a max time cap is hit, the session auto-ends.
  - Smarter optional trigger: if a user has been still and at their home
    coordinates for a while, treat the hangout as likely over.
  - The timer is the floor; the notification is the polite layer on top.

## Constraints (why the model looks the way it does)

These are iOS platform walls. They are not bugs to fix — the architecture above
already routes around all of them. Do not try to re-add the "magic" versions.

- **No background camera/photo monitoring.** iOS will not wake a suspended app
  when a new photo is taken. There is no permission or entitlement that unlocks
  this — Apple built it as a no-capability wall, not a permission wall. So the
  app acts at the bookend moments (join / leave) when it's already open.
- **No reliable proximity detection when the other app is closed.** BLE works
  poorly between backgrounded apps and not at all when force-quit. So we don't
  depend on live proximity; the session (formed at the start) defines the group.
- **Peer-to-peer requires both apps open.** Can't rely on it for delivery.
  Delivery goes through Supabase + push instead, so the receiver doesn't need
  their app open at send time.
- **Photos permission:** need full-library access to filter by time. iOS 14+
  limited access would break the time filter — prompt for full access with a
  clear explanation, and have a fallback for users who refuse.

## Tech stack

- **Client:** iOS native (SwiftUI assumed). iOS-only for v1.
- **Backend:** Supabase (auth, friend graph, session records, photo storage,
  per-recipient tagging). Team already knows Supabase.
- **Delivery:** push notifications (incl. silent push to wake app for download).
- **Photos:** PhotoKit / Photos framework, filtered by capture-date metadata.

**iOS-only is deliberate for v1.** Apple-specific transfer frameworks are not the
path (delivery is server-based), but native iOS is still the fastest route to
ship. Cross-platform (Android) is a v2 decision, not v1.

## App structure (4 tabs)

1. **Sessions** (home — app launches here)
   - Top: a prominent **"Start a roll"** button — creates a new session or joins
     by code. Always visible, especially when the list is empty (the empty state
     is when this button matters most).
   - Below: list of active + past sessions. Each row has its own controls
     (join / leave / end / view members) and a status indicator (active / ended).
2. **Contacts** — the friend graph. Needed so sessions know who's who.
3. **Unsent** — photos waiting to send + the review-and-deselect screen lives
   here. This is where the privacy guardrail surfaces.
4. **Settings** — last tab, secondary.

**Do NOT build an in-app received-photos gallery.** Photos land in the real
camera roll — that's the differentiator. An in-app gallery would undercut it.

## Voice / copy

Speak like a friend, not like software. Use the film-roll metaphor lightly for a
free, friendly vocabulary:
- "Start a roll" not "Create session"
- "Who's on the roll?" not "Session members"
- "Done hanging out?" not "Terminate session"

(Note: the chosen visual theme is white + green / "fresh & clean modern" rather
than heavy retro-film. Keep the *words* playful; keep the *look* clean. See
THEME.md.)

## Monetization

- 30-day free trial, then ~$3/month subscription.
- Costs are minimal: Supabase + $100/yr Apple Developer account.
- Don't gate so hard it kills the frictionless feel. Trial must be long enough
  that groups actually hang out and test it before the paywall.

## Growth model (build for this)

The app is **useless alone**, which is the growth engine: every user must recruit
friends to use it, so each user becomes a recruiter by design.

- Seed it in the founder's own friend group first ("I built this for us").
- **Make it fun at 2 people.** The magic moment (photos appearing effortlessly)
  must land with the smallest possible group, or the loop dies before it starts.
- **One-tap invite, surfaced at the peak moment** — right after photos
  auto-appear is when someone wants it for their other groups. Catch them there.

## Market position

The "event photo sharing" space is crowded (GuestPix, Kululu, GuestCam,
LiveWall, etc.) but those are host-driven, event-shaped, QR-code, upload-to-a-
gallery products. JustRoll's lane is the thin one: **no host, no setup, casual
everyday hangouts, auto-delivered to the camera roll.** Lead with that
difference or it blends in.

## v1 scope (keep it tight)

Build: accounts, friend graph, session create/join by code, join/leave
timestamps, photo-collection by capture-time, review-and-deselect screen,
Supabase upload + per-recipient tagging, push delivery + save to camera roll,
auto-off timer + nudge, the 4 tabs.

Don't build (yet): BLE proximity, QR joining, GPS, in-app gallery, Android,
AI anything. Add only if real usage demands it.

## Success metric

Not "number of users." The real signal is **retention inside the first ~100
users** — of the people who install, how many keep tapping it on three weeks
later, without being nagged. That number tells you whether the loop holds.
