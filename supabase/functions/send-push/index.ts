// =============================================================
// JustRoll — send-push Edge Function
//
// Sends APNs alert pushes for two events, always deriving the
// recipient list server-side from session_members (a client can
// never choose arbitrary recipients):
//
//   { "type": "memory",        "session_id": "...", "date_label": "today" }
//     → every member except the caller, gated by the recipient's
//       user_preferences.new_photos_enabled (default true).
//       "You have a memory from {circle}" / "Rolled by {sender} for {label}"
//
//   { "type": "member_joined", "session_id": "...", "joiner_name": "..."? }
//     → every member except the caller.
//       "{joiner} got added to {circle} via code"
//       joiner_name is only honored if it matches an actual member's
//       profile name (nearby-invite path, where the caller is the
//       creator, not the joiner); otherwise the caller's name is used.
//
// The caller must be an authenticated member of session_id.
//
// Secrets (Dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID   — Key ID of the APNs auth key
//   APNS_TEAM_ID  — Apple Developer Team ID
//   APNS_P8       — full contents of the .p8 file (BEGIN/END lines included)
//   APNS_TOPIC    — bundle id, com.justroll.app
//
// Deploy: supabase functions deploy send-push
// =============================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_P8 = Deno.env.get("APNS_P8") ?? "";
const APNS_TOPIC = Deno.env.get("APNS_TOPIC") ?? "com.justroll.app";

const APNS_PROD = "https://api.push.apple.com";
const APNS_SANDBOX = "https://api.sandbox.push.apple.com";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// ─── APNs provider JWT (ES256, cached ~50 min; Apple allows 20–60) ──

let cachedJwt: { token: string; issuedAt: number } | null = null;

function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJwt(): Promise<string> {
  if (cachedJwt && Date.now() - cachedJwt.issuedAt < 50 * 60 * 1000) {
    return cachedJwt.token;
  }
  const pemBody = APNS_P8.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID })));
  const payload = b64url(enc.encode(JSON.stringify({
    iss: APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  })));
  const unsigned = `${header}.${payload}`;
  // WebCrypto ECDSA signatures are already raw r||s — the JWS format.
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    enc.encode(unsigned),
  );
  const token = `${unsigned}.${b64url(new Uint8Array(sig))}`;
  cachedJwt = { token, issuedAt: Date.now() };
  return token;
}

// ─── Send one push; falls back to sandbox for dev-build tokens ──────

async function postToApns(host: string, deviceToken: string, body: unknown): Promise<{ ok: boolean; reason?: string }> {
  const res = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${await apnsJwt()}`,
      "apns-topic": APNS_TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (res.ok) return { ok: true };
  let reason = `status ${res.status}`;
  try {
    reason = (await res.json())?.reason ?? reason;
  } catch (_) { /* non-JSON error body */ }
  return { ok: false, reason };
}

async function sendPush(deviceToken: string, title: string, body: string, kind: string): Promise<void> {
  const payload = {
    aps: { alert: { title, body }, sound: "default" },
    kind,
  };
  const prod = await postToApns(APNS_PROD, deviceToken, payload);
  if (prod.ok) return;

  // Dev builds from Xcode register sandbox tokens; retry there once.
  if (prod.reason === "BadDeviceToken" || prod.reason === "Unregistered" || prod.reason === "DeviceTokenNotForTopic") {
    const sandbox = await postToApns(APNS_SANDBOX, deviceToken, payload);
    if (sandbox.ok) return;
    if (sandbox.reason === "BadDeviceToken" || sandbox.reason === "Unregistered") {
      // Dead on both environments — drop the token so we stop retrying it.
      await admin.from("device_tokens").delete().eq("token", deviceToken);
    }
    console.error(`APNs failed for ${deviceToken.slice(0, 8)}…: prod=${prod.reason} sandbox=${sandbox.reason}`);
    return;
  }
  console.error(`APNs failed for ${deviceToken.slice(0, 8)}…: ${prod.reason}`);
}

// ─── Handler ────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // Identify the caller from their JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const { data: userData, error: authError } = await admin.auth.getUser(
    authHeader.replace(/^Bearer\s+/i, ""),
  );
  const callerId = userData?.user?.id;
  if (authError || !callerId) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let body: { type?: string; session_id?: string; date_label?: string; joiner_name?: string };
  try {
    body = await req.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: "invalid json" }), { status: 400 });
  }
  const { type, session_id: sessionId } = body;
  if ((type !== "memory" && type !== "member_joined") || !sessionId) {
    return new Response(JSON.stringify({ error: "invalid payload" }), { status: 400 });
  }

  // Session + members; the caller must be one of them.
  const { data: session } = await admin
    .from("sessions").select("id, name").eq("id", sessionId).maybeSingle();
  if (!session) {
    return new Response(JSON.stringify({ error: "session not found" }), { status: 404 });
  }
  const { data: members } = await admin
    .from("session_members").select("user_id").eq("session_id", sessionId);
  const memberIds: string[] = (members ?? []).map((m) => m.user_id);
  if (!memberIds.includes(callerId)) {
    return new Response(JSON.stringify({ error: "not a member" }), { status: 403 });
  }

  let recipientIds = memberIds.filter((id) => id !== callerId);

  const { data: profiles } = await admin
    .from("profiles").select("id, name").in("id", memberIds);
  const nameOf = new Map((profiles ?? []).map((p) => [p.id, p.name as string]));
  const callerName = nameOf.get(callerId) ?? "Someone";

  let title: string;
  let text: string;
  if (type === "memory") {
    // Respect each recipient's "New photos" preference (no row = enabled).
    const { data: prefs } = await admin
      .from("user_preferences")
      .select("user_id, new_photos_enabled")
      .in("user_id", recipientIds);
    const muted = new Set((prefs ?? []).filter((p) => p.new_photos_enabled === false).map((p) => p.user_id));
    recipientIds = recipientIds.filter((id) => !muted.has(id));

    const label = (body.date_label ?? "today").slice(0, 40);
    title = `You have a memory from ${session.name}`;
    text = `Rolled by ${callerName} for ${label}`;
  } else {
    // joiner_name is trusted only if it names an actual member (nearby-invite
    // path, where the creator sends on the joiner's behalf).
    const memberNames = new Set(nameOf.values());
    const joiner = body.joiner_name && memberNames.has(body.joiner_name)
      ? body.joiner_name
      : callerName;
    title = session.name;
    text = `${joiner} got added to ${session.name} via code`;
    // Don't notify the joiner about their own arrival.
    const joinerId = [...nameOf.entries()].find(([, n]) => n === joiner)?.[0];
    if (joinerId) recipientIds = recipientIds.filter((id) => id !== joinerId);
  }

  if (recipientIds.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const { data: tokens } = await admin
    .from("device_tokens").select("token").in("user_id", recipientIds);
  const deviceTokens: string[] = (tokens ?? []).map((t) => t.token);

  await Promise.all(deviceTokens.map((t) => sendPush(t, title, text, type)));

  return new Response(
    JSON.stringify({ sent: deviceTokens.length, recipients: recipientIds.length }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
});
