-- =============================================================
-- JustRoll — Delete Account (App Store Guideline 5.1.1(v))
--
-- Paste this ENTIRE file into the Supabase SQL Editor and run it
-- ONCE. It is safe to re-run (CREATE OR REPLACE + IF EXISTS/
-- idempotent DDL throughout), so re-running after edits is fine.
--
-- Schema this was written against: schema.sql at the repo root,
-- cross-checked against every query in
-- JustRoll/JustRoll/Services/SupabaseService.swift. Tables/bucket
-- touched:
--   public.profiles           (id, name, username, email, avatar_id, ...)
--   public.sessions           (id, code, name, kind, status, creator_id, ...)
--   public.session_members    (session_id, user_id, joined_at, left_at, ...)
--   public.contacts           (id, requester_id, addressee_id, status)
--   public.photos             (id, session_id, uploader_id, storage_path,
--                               thumbnail_path, capture_date)
--   public.photo_deliveries   (photo_id, recipient_id, sender_id,
--                               session_id, status, delivered_at)
--   storage bucket "photos"   — objects at
--                               "<session_id>/<uploader_id>/<photo_id>_full.jpg"
--                               and "..._thumb.jpg" (see uploadPhotos() in
--                               SupabaseService.swift — the uid is the
--                               MIDDLE path segment, not a prefix)
-- =============================================================

-- ─── Prerequisite: let sessions survive a deleted creator ──────
-- public.sessions.creator_id is declared
--   creator_id UUID NOT NULL REFERENCES public.profiles(id)
-- with no ON DELETE action (defaults to RESTRICT/NO ACTION). If the
-- deleted user CREATED a session that other people are still members of,
-- deleting their profiles row later in this script would otherwise fail
-- with a foreign-key violation. Relax the FK so creator_id is nulled out
-- instead — the session (and its remaining members) survives; it just
-- loses its "creator" attribution, which only ever gated the
-- invite-to-session / delete-session actions for that one user.
--
-- NOTE: this assumes the default Postgres-generated constraint name
-- "sessions_creator_id_fkey" (true when the FK is declared inline, as it
-- is in schema.sql). If your project has since renamed it, the DROP
-- CONSTRAINT below will just no-op (IF EXISTS) and the ADD CONSTRAINT
-- will fail loudly — check `\d public.sessions` in that case and adjust
-- the name.
ALTER TABLE public.sessions
  ALTER COLUMN creator_id DROP NOT NULL;

ALTER TABLE public.sessions
  DROP CONSTRAINT IF EXISTS sessions_creator_id_fkey;

ALTER TABLE public.sessions
  ADD CONSTRAINT sessions_creator_id_fkey
    FOREIGN KEY (creator_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ─── delete_account() ───────────────────────────────────────────
-- Called from the client as: client.rpc("delete_account").execute()
-- Takes NO parameters and operates ONLY on auth.uid() — a signed-in user
-- can only ever delete themselves, never another account.
--
-- Deletes, in dependency order:
--   1. photo_deliveries where this user is the RECIPIENT (their inbox
--      tags for photos other people sent them).
--   2. Storage objects for photos this user UPLOADED (bucket "photos").
--   3. photos rows this user uploaded — cascades (ON DELETE CASCADE on
--      photo_deliveries.photo_id) to any remaining delivery rows for
--      those photos, e.g. tags for recipients other than this user.
--   4. ALL session_members rows for this user — this is the "remove
--      the user from EVERY circle" requirement. Non-negotiable per
--      App Store 5.1.1(v).
--   5. Any session left with zero members afterwards — mirrors the
--      app's own leaveSession() behavior (SupabaseService.swift), which
--      already deletes a circle once its last member leaves. Orphaned
--      photos on those sessions are cleared first so photos.session_id's
--      FK (no ON DELETE action) doesn't block the session delete.
--   6. contacts rows in both directions (requester or addressee).
--   7. The profiles row.
--   8. auth.users row — this is what actually removes the account.
--      profiles.id already cascades from this (ON DELETE CASCADE), so
--      step 7 is belt-and-suspenders, not load-bearing.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_orphaned_session_ids uuid[];
begin
  if v_uid is null then
    raise exception 'delete_account() must be called by an authenticated user';
  end if;

  -- 1. Deliveries where this user is the recipient (photos others sent them)
  delete from public.photo_deliveries
  where recipient_id = v_uid;

  -- 2. Storage objects for photos this user uploaded.
  -- Path convention is "<session_id>/<uid>/<photo_id>_full.jpg" (and
  -- "_thumb.jpg") — the uid is the middle segment, not a prefix — so match
  -- on that, plus the storage "owner" column as a belt-and-suspenders check.
  delete from storage.objects
  where bucket_id = 'photos'
    and (
      name like '%/' || v_uid::text || '/%'
      or owner = v_uid
    );

  -- 3. Photos this user uploaded (cascades their remaining delivery rows)
  delete from public.photos
  where uploader_id = v_uid;

  -- 4. Leave every circle this user belongs to — the core requirement
  delete from public.session_members
  where user_id = v_uid;

  -- 5. Sessions that are now empty (no members left at all). Collect ids
  -- first so orphaned photo rows can be cleared before the session delete
  -- (photos.session_id has no ON DELETE action, so it would otherwise
  -- block deleting a session that still has photo rows pointing at it).
  select array_agg(s.id) into v_orphaned_session_ids
  from public.sessions s
  where not exists (
    select 1 from public.session_members sm where sm.session_id = s.id
  );

  if v_orphaned_session_ids is not null then
    delete from public.photos where session_id = any(v_orphaned_session_ids);
    delete from public.sessions where id = any(v_orphaned_session_ids);
  end if;

  -- 6. Friend graph, both directions
  delete from public.contacts
  where requester_id = v_uid or addressee_id = v_uid;

  -- 7. Profile row
  delete from public.profiles
  where id = v_uid;

  -- 8. The account itself. Everything above exists only to unblock this:
  -- session_members / photos / contacts / photo_deliveries all reference
  -- profiles(id) without ON DELETE CASCADE, so they must be cleared (or,
  -- for sessions.creator_id, relaxed to SET NULL) before this can succeed.
  delete from auth.users where id = v_uid;
end;
$$;

alter function public.delete_account() owner to postgres;

revoke all on function public.delete_account() from public;
revoke execute on function public.delete_account() from anon;
grant execute on function public.delete_account() to authenticated;
