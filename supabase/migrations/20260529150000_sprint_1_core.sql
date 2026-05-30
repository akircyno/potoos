-- =========================================================
-- LitratoLink Sprint 1 Core Migration
-- Purpose: original-quality upload/download proof
-- =========================================================

create extension if not exists "pgcrypto";

do $$
begin
  if not exists (select 1 from pg_type where typname = 'album_role') then
    create type public.album_role as enum ('admin', 'contributor', 'viewer');
  end if;

  if not exists (select 1 from pg_type where typname = 'media_file_type') then
    create type public.media_file_type as enum ('photo', 'video');
  end if;

  if not exists (select 1 from pg_type where typname = 'upload_status') then
    create type public.upload_status as enum ('pending', 'uploading', 'completed', 'failed');
  end if;

  if not exists (select 1 from pg_type where typname = 'storage_provider_type') then
    create type public.storage_provider_type as enum (
      'google_drive',
      'cloudflare_r2',
      'google_cloud_storage',
      'supabase_storage'
    );
  end if;
end $$;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_active_at timestamptz,
  is_active boolean not null default true,
  is_banned boolean not null default false
);

create table if not exists public.storage_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type public.storage_provider_type not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.albums (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  name text not null,
  description text,
  storage_provider_id uuid references public.storage_providers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  delete_expires_at timestamptz,
  is_archived boolean not null default false,

  constraint albums_name_length_check check (char_length(name) between 1 and 100)
);

create table if not exists public.album_members (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  role public.album_role not null,
  invited_by uuid references public.user_profiles(id),
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  is_active boolean not null default true,

  constraint album_members_unique_album_user unique (album_id, user_id)
);

create table if not exists public.storage_objects (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.storage_providers(id),
  provider_file_id text,
  provider_folder_id text,
  storage_path text,
  file_size_bytes bigint not null,
  mime_type text not null,
  checksum text,
  created_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  deleted_at timestamptz,

  constraint storage_objects_file_size_check check (file_size_bytes >= 0)
);

create table if not exists public.media_files (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  uploader_id uuid not null references public.user_profiles(id) on delete cascade,
  storage_object_id uuid references public.storage_objects(id),
  original_filename text not null,
  file_type public.media_file_type not null,
  mime_type text not null,
  file_size_bytes bigint not null,
  width integer,
  height integer,
  duration_seconds numeric,
  upload_status public.upload_status not null default 'pending',
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  delete_expires_at timestamptz,
  deleted_by uuid references public.user_profiles(id),
  restored_at timestamptz,
  permanently_deleted_at timestamptz,

  constraint media_files_file_size_check check (file_size_bytes > 0),
  constraint media_files_filename_length_check check (char_length(original_filename) between 1 and 255)
);

create index if not exists user_profiles_email_idx on public.user_profiles (email);
create index if not exists albums_owner_id_idx on public.albums (owner_id);
create index if not exists albums_is_deleted_idx on public.albums (is_deleted);
create index if not exists albums_updated_at_idx on public.albums (updated_at);
create index if not exists album_members_album_id_idx on public.album_members (album_id);
create index if not exists album_members_user_id_idx on public.album_members (user_id);
create index if not exists album_members_album_user_idx on public.album_members (album_id, user_id);
create index if not exists album_members_album_role_idx on public.album_members (album_id, role);
create index if not exists storage_objects_provider_id_idx on public.storage_objects (provider_id);
create index if not exists media_files_album_id_idx on public.media_files (album_id);
create index if not exists media_files_uploader_id_idx on public.media_files (uploader_id);
create index if not exists media_files_album_deleted_idx on public.media_files (album_id, is_deleted);
create index if not exists media_files_upload_status_idx on public.media_files (upload_status);
create index if not exists media_files_delete_expires_at_idx on public.media_files (delete_expires_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_profiles_updated_at on public.user_profiles;
create trigger set_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_albums_updated_at on public.albums;
create trigger set_albums_updated_at
before update on public.albums
for each row execute function public.set_updated_at();

drop trigger if exists set_media_files_updated_at on public.media_files;
create trigger set_media_files_updated_at
before update on public.media_files
for each row execute function public.set_updated_at();

create or replace function public.is_album_member(
  target_album_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.album_members am
    join public.albums a on a.id = am.album_id
    where am.album_id = target_album_id
      and am.user_id = target_user_id
      and am.is_active = true
      and a.is_deleted = false
  );
$$;

create or replace function public.get_album_role(
  target_album_id uuid,
  target_user_id uuid
)
returns public.album_role
language sql
stable
security definer
set search_path = public
as $$
  select am.role
  from public.album_members am
  join public.albums a on a.id = am.album_id
  where am.album_id = target_album_id
    and am.user_id = target_user_id
    and am.is_active = true
    and a.is_deleted = false
  limit 1;
$$;

create or replace function public.is_album_admin(
  target_album_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.album_members am
    join public.albums a on a.id = am.album_id
    where am.album_id = target_album_id
      and am.user_id = target_user_id
      and am.role = 'admin'
      and am.is_active = true
      and a.is_deleted = false
  );
$$;

create or replace function public.can_upload_to_album(
  target_album_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.album_members am
    join public.albums a on a.id = am.album_id
    where am.album_id = target_album_id
      and am.user_id = target_user_id
      and am.role in ('admin', 'contributor')
      and am.is_active = true
      and a.is_deleted = false
  );
$$;

create or replace function public.is_file_uploader(
  target_media_file_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.media_files mf
    where mf.id = target_media_file_id
      and mf.uploader_id = target_user_id
  );
$$;

create or replace function public.album_has_other_admin(
  target_album_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.album_members am
    where am.album_id = target_album_id
      and am.user_id <> target_user_id
      and am.role = 'admin'
      and am.is_active = true
  );
$$;

alter table public.user_profiles enable row level security;
alter table public.storage_providers enable row level security;
alter table public.albums enable row level security;
alter table public.album_members enable row level security;
alter table public.storage_objects enable row level security;
alter table public.media_files enable row level security;

drop policy if exists "Users can read own profile" on public.user_profiles;
drop policy if exists "Users can insert own profile" on public.user_profiles;
drop policy if exists "Users can update own profile" on public.user_profiles;
drop policy if exists "Users can read active storage providers" on public.storage_providers;
drop policy if exists "Members can read albums" on public.albums;
drop policy if exists "Users can create own albums" on public.albums;
drop policy if exists "Admins can update albums" on public.albums;
drop policy if exists "Members can read album members" on public.album_members;
drop policy if exists "Admins can insert album members" on public.album_members;
drop policy if exists "Admins can update album members" on public.album_members;
drop policy if exists "Members can read storage objects through media files" on public.storage_objects;
drop policy if exists "Members can read active media files" on public.media_files;
drop policy if exists "Uploaders can read own deleted media files" on public.media_files;
drop policy if exists "Uploaders can insert media files" on public.media_files;
drop policy if exists "Uploaders can update own pending media files" on public.media_files;

create policy "Users can read own profile"
on public.user_profiles
for select
to authenticated
using (id = (select auth.uid()));

create policy "Users can insert own profile"
on public.user_profiles
for insert
to authenticated
with check (id = (select auth.uid()));

create policy "Users can update own profile"
on public.user_profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "Users can read active storage providers"
on public.storage_providers
for select
to authenticated
using (is_active = true);

create policy "Members can read albums"
on public.albums
for select
to authenticated
using (public.is_album_member(id, (select auth.uid())));

create policy "Users can create own albums"
on public.albums
for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "Admins can update albums"
on public.albums
for update
to authenticated
using (public.is_album_admin(id, (select auth.uid())))
with check (public.is_album_admin(id, (select auth.uid())));

create policy "Members can read album members"
on public.album_members
for select
to authenticated
using (public.is_album_member(album_id, (select auth.uid())));

create policy "Admins can insert album members"
on public.album_members
for insert
to authenticated
with check (public.is_album_admin(album_id, (select auth.uid())));

create policy "Admins can update album members"
on public.album_members
for update
to authenticated
using (public.is_album_admin(album_id, (select auth.uid())))
with check (public.is_album_admin(album_id, (select auth.uid())));

create policy "Members can read storage objects through media files"
on public.storage_objects
for select
to authenticated
using (
  exists (
    select 1
    from public.media_files mf
    where mf.storage_object_id = storage_objects.id
      and public.is_album_member(mf.album_id, (select auth.uid()))
      and mf.upload_status = 'completed'
      and mf.is_deleted = false
      and mf.permanently_deleted_at is null
  )
);

create policy "Members can read active media files"
on public.media_files
for select
to authenticated
using (
  public.is_album_member(album_id, (select auth.uid()))
  and upload_status = 'completed'
  and is_deleted = false
  and permanently_deleted_at is null
);

create policy "Uploaders can read own deleted media files"
on public.media_files
for select
to authenticated
using (
  uploader_id = (select auth.uid())
  and is_deleted = true
  and permanently_deleted_at is null
);

create policy "Uploaders can insert media files"
on public.media_files
for insert
to authenticated
with check (
  uploader_id = (select auth.uid())
  and public.can_upload_to_album(album_id, (select auth.uid()))
  and upload_status in ('pending', 'uploading')
);

create policy "Uploaders can update own pending media files"
on public.media_files
for update
to authenticated
using (
  uploader_id = (select auth.uid())
  and upload_status in ('pending', 'uploading', 'failed')
)
with check (
  uploader_id = (select auth.uid())
  and upload_status in ('pending', 'uploading', 'failed')
);

grant usage on schema public to authenticated, service_role;

grant select, insert, update on public.user_profiles to authenticated;
grant select on public.storage_providers to authenticated;
grant select, insert, update on public.albums to authenticated;
grant select, insert, update on public.album_members to authenticated;
grant select on public.storage_objects to authenticated;
grant select, insert, update on public.media_files to authenticated;

grant all privileges on public.user_profiles to service_role;
grant all privileges on public.storage_providers to service_role;
grant all privileges on public.albums to service_role;
grant all privileges on public.album_members to service_role;
grant all privileges on public.storage_objects to service_role;
grant all privileges on public.media_files to service_role;

insert into public.storage_providers (name, type, is_active)
select 'Google Drive Main', 'google_drive', true
where not exists (
  select 1
  from public.storage_providers
  where type = 'google_drive'
    and name = 'Google Drive Main'
);
