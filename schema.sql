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

-- Storage RLS (add via dashboard under Storage → Policies):
-- Allow authenticated upload:
--   bucket_id = 'photos' AND auth.uid() IS NOT NULL  → INSERT
-- Allow member download:
--   bucket_id = 'photos' AND auth.uid() IS NOT NULL  → SELECT
