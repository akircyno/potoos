-- =========================================================
-- Album Invites
-- Separates the invite flow from direct membership.
-- New invites sit in album_invites with status='pending' until
-- the recipient accepts or declines.
-- =========================================================

create table if not exists public.album_invites (
  id              uuid primary key default gen_random_uuid(),
  album_id        uuid not null references public.albums(id) on delete cascade,
  invited_user_id uuid not null references public.user_profiles(id) on delete cascade,
  invited_by_id   uuid not null references public.user_profiles(id) on delete cascade,
  -- Denormalised so the invite card can be rendered without a second join
  -- through albums RLS (invited user is not yet a member at read-time).
  invited_by_name text not null default '',
  album_name      text not null default '',
  role            public.album_role not null default 'contributor',
  status          text not null default 'pending'
                    constraint album_invites_status_check
                    check (status in ('pending', 'accepted', 'declined')),
  created_at      timestamptz not null default now(),
  responded_at    timestamptz
);

-- Only one *pending* invite per album + user. Re-inviting after a decline or
-- acceptance is allowed (new row).
create unique index album_invites_one_pending_idx
  on public.album_invites (album_id, invited_user_id)
  where status = 'pending';

alter table public.album_invites enable row level security;

-- Invited user can read their own invites (any status, so they can see history).
create policy "Users can read their own invites"
  on public.album_invites for select
  using (invited_user_id = auth.uid());

-- Album admin can read invites they manage.
create policy "Admins can read album invites"
  on public.album_invites for select
  using (is_album_admin(album_id, auth.uid()));

-- Allow invited users (pending only) to read basic album info so the invite
-- card can display the album name and cover thumbnail.
create policy "Pending invite: read album basics"
  on public.albums for select
  using (
    exists (
      select 1 from public.album_invites
      where album_invites.album_id = albums.id
        and album_invites.invited_user_id = auth.uid()
        and album_invites.status = 'pending'
    )
  );
