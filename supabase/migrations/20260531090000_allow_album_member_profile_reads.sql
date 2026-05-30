-- Allow active album members to see basic profile details for people
-- who are active members of the same album.

drop policy if exists "Members can read fellow album member profiles"
on public.user_profiles;

create policy "Members can read fellow album member profiles"
on public.user_profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from public.album_members member_profile
    where member_profile.user_id = user_profiles.id
      and member_profile.is_active = true
      and public.is_album_member(
        member_profile.album_id,
        (select auth.uid())
      )
  )
);
