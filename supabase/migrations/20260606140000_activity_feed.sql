-- Activity events feed
-- Tracks user actions across albums for the real-time activity feed.

CREATE TABLE IF NOT EXISTS public.activity_events (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id       UUID        NOT NULL REFERENCES public.albums(id) ON DELETE CASCADE,
  actor_id       UUID        NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  event_type     TEXT        NOT NULL CHECK (event_type IN (
                               'file_uploaded', 'member_joined', 'member_left',
                               'member_declined', 'album_created'
                             )),
  metadata       JSONB       NOT NULL DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS activity_events_album_created_idx
  ON public.activity_events(album_id, created_at DESC);

CREATE INDEX IF NOT EXISTS activity_events_actor_idx
  ON public.activity_events(actor_id);

-- Tracks when each user last read their activity feed (for unread badge).
CREATE TABLE IF NOT EXISTS public.user_activity_reads (
  user_id      UUID        PRIMARY KEY REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: only active album members can read events for that album.
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members_can_read_album_activity"
  ON public.activity_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.album_members
      WHERE album_members.album_id = activity_events.album_id
        AND album_members.user_id  = auth.uid()
        AND album_members.is_active = true
    )
  );

-- RLS: each user manages only their own read record.
ALTER TABLE public.user_activity_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_manage_own_activity_reads"
  ON public.user_activity_reads
  FOR ALL
  USING   (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
