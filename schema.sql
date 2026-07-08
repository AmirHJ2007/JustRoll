-- =============================================================
-- JustRoll — Supabase Schema
-- Paste the entire contents of this file into the Supabase SQL
-- Editor and run it. Run once on a fresh project.
-- =============================================================

-- ─── Custom types ────────────────────────────────────────────

CREATE TYPE session_kind   AS ENUM ('disposable', 'lasting');
CREATE TYPE session_status AS ENUM ('pending', 'active', 'ended');
CREATE TYPE contact_status AS ENUM ('pending', 'accepted', 'rejected');

-- ─── profiles ────────────────────────────────────────────────
-- One row per user, linked to auth.users.
-- Created automatically via trigger on sign-up.

CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  username    TEXT UNIQUE NOT NULL,
  email       TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Trigger: insert a profile row whenever a new auth user is created.
-- name and username are passed as user_metadata on sign-up.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, username)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── sessions ────────────────────────────────────────────────

CREATE TABLE public.sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        VARCHAR(5) UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  kind        session_kind   NOT NULL,
  status      session_status NOT NULL DEFAULT 'pending',
  creator_id  UUID NOT NULL REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ DEFAULT now(),
  ended_at    TIMESTAMPTZ
);

CREATE INDEX ON public.sessions(code);
CREATE INDEX ON public.sessions(creator_id);

-- ─── session_members ─────────────────────────────────────────
-- Join/leave timestamps define who-gets-what per photo.

CREATE TABLE public.session_members (
  session_id          UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES public.profiles(id),
  joined_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at             TIMESTAMPTZ,
  is_rolling          BOOLEAN NOT NULL DEFAULT FALSE,
  rolling_started_at  TIMESTAMPTZ,          -- set when user taps "Start rolling"
  rolling_stopped_at  TIMESTAMPTZ,          -- set when user taps "Stop rolling"
  batch_sent          BOOLEAN NOT NULL DEFAULT FALSE,  -- true after photos reviewed & sent
  PRIMARY KEY (session_id, user_id)
);

-- Migration (run on existing DB — skip if creating fresh):
-- ALTER TABLE public.session_members
--   ADD COLUMN rolling_started_at  TIMESTAMPTZ,
--   ADD COLUMN rolling_stopped_at  TIMESTAMPTZ,
--   ADD COLUMN batch_sent          BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX ON public.session_members(user_id);
CREATE INDEX ON public.session_members(session_id);

-- ─── contacts ────────────────────────────────────────────────
-- Mutual friendship model: requester sends, addressee accepts.

CREATE TABLE public.contacts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES public.profiles(id),
  addressee_id UUID NOT NULL REFERENCES public.profiles(id),
  status       contact_status NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (requester_id, addressee_id),
  CHECK (requester_id != addressee_id)
);

CREATE INDEX ON public.contacts(requester_id);
CREATE INDEX ON public.contacts(addressee_id);

-- ─── photos ──────────────────────────────────────────────────
-- One row per uploaded photo. Actual file lives in Storage.

CREATE TABLE public.photos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID NOT NULL REFERENCES public.sessions(id),
  uploader_id   UUID NOT NULL REFERENCES public.profiles(id),
  storage_path  TEXT NOT NULL,
  capture_date  TIMESTAMPTZ NOT NULL,
  uploaded_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON public.photos(session_id);
CREATE INDEX ON public.photos(uploader_id);

-- ─── photo_deliveries ────────────────────────────────────────
-- Per-recipient delivery tracking. Null delivered_at = not yet saved.

CREATE TABLE public.photo_deliveries (
  photo_id      UUID NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  recipient_id  UUID NOT NULL REFERENCES public.profiles(id),
  delivered_at  TIMESTAMPTZ,
  PRIMARY KEY (photo_id, recipient_id)
);

CREATE INDEX ON public.photo_deliveries(recipient_id);

-- ─── user_preferences ────────────────────────────────────────

CREATE TABLE public.user_preferences (
  user_id              UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  nudges_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
  new_photos_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- Row Level Security
-- =============================================================

-- ─── profiles ────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated users can read all profiles"
  ON public.profiles FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- ─── sessions ────────────────────────────────────────────────
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members can read their sessions"
  ON public.sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_members
      WHERE session_members.session_id = sessions.id
        AND session_members.user_id = auth.uid()
    )
  );

CREATE POLICY "authenticated users can create sessions"
  ON public.sessions FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND creator_id = auth.uid());

CREATE POLICY "creators can update their session"
  ON public.sessions FOR UPDATE
  USING (creator_id = auth.uid());

CREATE POLICY "creators can delete their session"
  ON public.sessions FOR DELETE
  USING (creator_id = auth.uid());

-- ─── session_members ─────────────────────────────────────────
ALTER TABLE public.session_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members can read all members of shared sessions"
  ON public.session_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_members sm2
      WHERE sm2.session_id = session_members.session_id
        AND sm2.user_id = auth.uid()
    )
  );

CREATE POLICY "authenticated users can join sessions"
  ON public.session_members FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "members can update their own row"
  ON public.session_members FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "members can leave (delete their row)"
  ON public.session_members FOR DELETE
  USING (user_id = auth.uid());

-- ─── contacts ────────────────────────────────────────────────
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "parties can see their contact rows"
  ON public.contacts FOR SELECT
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

CREATE POLICY "authenticated users can send contact requests"
  ON public.contacts FOR INSERT
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "addressee can accept or reject"
  ON public.contacts FOR UPDATE
  USING (addressee_id = auth.uid());

CREATE POLICY "either party can remove the contact"
  ON public.contacts FOR DELETE
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

-- ─── photos ──────────────────────────────────────────────────
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session members can read photos"
  ON public.photos FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_members
      WHERE session_members.session_id = photos.session_id
        AND session_members.user_id = auth.uid()
    )
  );

CREATE POLICY "members can upload photos to their sessions"
  ON public.photos FOR INSERT
  WITH CHECK (
    uploader_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.session_members
      WHERE session_members.session_id = photos.session_id
        AND session_members.user_id = auth.uid()
    )
  );

-- ─── photo_deliveries ────────────────────────────────────────
ALTER TABLE public.photo_deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipients can read their deliveries"
  ON public.photo_deliveries FOR SELECT
  USING (recipient_id = auth.uid());

CREATE POLICY "uploaders can insert deliveries"
  ON public.photo_deliveries FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.photos
      WHERE photos.id = photo_deliveries.photo_id
        AND photos.uploader_id = auth.uid()
    )
  );

CREATE POLICY "recipients can mark as delivered"
  ON public.photo_deliveries FOR UPDATE
  USING (recipient_id = auth.uid());

-- ─── user_preferences ────────────────────────────────────────
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users own their preferences"
  ON public.user_preferences FOR ALL
  USING (user_id = auth.uid());

-- =============================================================
-- Storage bucket
-- Run this separately in the Supabase dashboard:
--   Storage → New bucket → name: "photos" → Private
-- Or via SQL:
-- =============================================================
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('photos', 'photos', false);

-- Storage RLS: DO NOT use permissive "auth.uid() IS NOT NULL" policies —
-- they let any signed-in user read any photo. Use the member-scoped
-- policies in the "security hardening" migration at the end of this file.

-- =============================================================
-- Migration: nearby invite (run in Supabase SQL editor)
-- Allows the session creator to add a nearby user by username,
-- bypassing the RLS policy that only lets users add themselves.
-- =============================================================

CREATE OR REPLACE FUNCTION invite_to_session(p_session_id UUID, p_username TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Only the session creator can invite
  IF NOT EXISTS (
    SELECT 1 FROM public.sessions
    WHERE id = p_session_id AND creator_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Only the session creator can invite members';
  END IF;

  SELECT id INTO v_user_id FROM public.profiles WHERE username = p_username;
  IF v_user_id IS NULL THEN RETURN; END IF;  -- silently skip unknown usernames

  INSERT INTO public.session_members (session_id, user_id)
  VALUES (p_session_id, v_user_id)
  ON CONFLICT DO NOTHING;
END;
$$;

-- =============================================================
-- Migration: photo delivery pipeline (run AFTER initial schema)
-- =============================================================

-- Add thumbnail path to photos table
ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS thumbnail_path TEXT;

-- Add status + sender + session tracking to photo_deliveries
ALTER TABLE public.photo_deliveries
  ADD COLUMN IF NOT EXISTS status     TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS sender_id  UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.sessions(id);

-- Backfill: existing delivered rows → saved
UPDATE public.photo_deliveries SET status = 'saved' WHERE delivered_at IS NOT NULL;

-- RLS: recipients can update their own delivery status
DROP POLICY IF EXISTS "recipient can update delivery status" ON public.photo_deliveries;
CREATE POLICY "recipient can update delivery status"
  ON public.photo_deliveries FOR UPDATE
  USING (recipient_id = auth.uid());

-- Auto-cleanup: delete photos where all deliveries are resolved (runs hourly)
SELECT cron.schedule(
  'cleanup-resolved-photos',
  '0 * * * *',
  $$
    DELETE FROM public.photos
    WHERE id IN (
      SELECT p.id FROM public.photos p
      WHERE NOT EXISTS (
        SELECT 1 FROM public.photo_deliveries d
        WHERE d.photo_id = p.id AND d.status = 'pending'
      )
    );
  $$
);

-- RPC: return storage paths for fully-resolved photos in a session (used for client-side cleanup)
CREATE OR REPLACE FUNCTION get_fully_resolved_photos(p_session_id UUID)
RETURNS TABLE(storage_path TEXT, thumbnail_path TEXT) AS $$
  SELECT p.storage_path, p.thumbnail_path
  FROM public.photos p
  WHERE p.session_id = p_session_id
    AND NOT EXISTS (
      SELECT 1 FROM public.photo_deliveries d
      WHERE d.photo_id = p.id AND d.status = 'pending'
    );
$$ LANGUAGE sql SECURITY DEFINER;

-- =============================================================
-- Migration: preset avatars (run in Supabase SQL editor)
-- Adds a nullable avatar_id (1-12, references bundled preset
-- images in the app). NULL = initials fallback.
-- =============================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_id INT;

-- Recreate the sign-up trigger function so new users get their
-- chosen avatar from auth metadata (nullable-safe cast to INT).
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, username, avatar_id)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'username',
    NULLIF(NEW.raw_user_meta_data->>'avatar_id', '')::INT
  );
  RETURN NEW;
END;
$$;

-- =============================================================
-- Migration: username availability check (run in SQL editor)
-- Lets the onboarding flow verify a handle is free BEFORE the
-- account exists. SECURITY DEFINER because anon users cannot
-- read profiles under RLS.
-- =============================================================

CREATE OR REPLACE FUNCTION username_available(p_username TEXT)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE lower(username) = lower(p_username)
  );
$$;

GRANT EXECUTE ON FUNCTION username_available(TEXT) TO anon, authenticated;

-- =============================================================
-- Migration: push notifications (run in Supabase SQL editor)
-- APNs device tokens, one row per device. The send-push Edge
-- Function reads these with the service role to deliver pushes.
-- =============================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  token       TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users own their device tokens" ON public.device_tokens;
CREATE POLICY "users own their device tokens"
  ON public.device_tokens FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =============================================================
-- Migration: security hardening (run in Supabase SQL editor)
--
-- Fixes two holes found in a pre-TestFlight security audit:
--
--  A. The storage bucket policies suggested earlier in this file
--     ("auth.uid() IS NOT NULL" for SELECT/INSERT) let ANY signed-in
--     user download ANY photo if they learn its path. Replace them
--     with member-scoped policies below.
--
--     ⚠️ FIRST: Dashboard → Storage → Policies → bucket "photos":
--     delete the old permissive SELECT / INSERT policies you created
--     from this file's earlier instructions (whatever they're named),
--     then run this block.
--
--  B. get_fully_resolved_photos() was SECURITY DEFINER with no
--     membership check — any signed-in user could enumerate storage
--     paths for any session. Recreated as SECURITY INVOKER so the
--     caller's own RLS on public.photos (member-only SELECT) applies.
--
-- Storage path convention (see uploadPhotos in SupabaseService.swift):
--   {session_id}/{uploader_id}/{photo_id}_full.jpg|mp4  and  ..._thumb.jpg
-- so (storage.foldername(name))[1] = session_id
--    (storage.foldername(name))[2] = uploader_id
-- =============================================================

DROP POLICY IF EXISTS "members read their sessions' photos" ON storage.objects;
CREATE POLICY "members read their sessions' photos"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'photos'
    AND EXISTS (
      SELECT 1 FROM public.session_members sm
      WHERE sm.session_id::text = (storage.foldername(name))[1]
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "uploaders write into their own folder" ON storage.objects;
CREATE POLICY "uploaders write into their own folder"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (
      SELECT 1 FROM public.session_members sm
      WHERE sm.session_id::text = (storage.foldername(name))[1]
        AND sm.user_id = auth.uid()
    )
  );

-- Member-scoped (not uploader-scoped) on purpose: deleteSessionCascade in
-- SupabaseService.swift removes OTHER members' objects when a circle is
-- deleted, and the client-side cleanup deletes fully-resolved photos too.
DROP POLICY IF EXISTS "members delete their sessions' photos" ON storage.objects;
CREATE POLICY "members delete their sessions' photos"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'photos'
    AND EXISTS (
      SELECT 1 FROM public.session_members sm
      WHERE sm.session_id::text = (storage.foldername(name))[1]
        AND sm.user_id = auth.uid()
    )
  );

-- B: RLS-respecting rewrite. SECURITY INVOKER (the default) means the
-- photos-table policy "session members can read photos" now gates it.
CREATE OR REPLACE FUNCTION get_fully_resolved_photos(p_session_id UUID)
RETURNS TABLE(storage_path TEXT, thumbnail_path TEXT)
LANGUAGE sql SECURITY INVOKER AS $$
  SELECT p.storage_path, p.thumbnail_path
  FROM public.photos p
  WHERE p.session_id = p_session_id
    AND NOT EXISTS (
      SELECT 1 FROM public.photo_deliveries d
      WHERE d.photo_id = p.id AND d.status = 'pending'
    );
$$;
