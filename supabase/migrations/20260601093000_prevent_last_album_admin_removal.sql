-- Enforce the "at least one active Admin" rule at the database layer.

create or replace function public.prevent_last_album_admin_removal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.role = 'admin'
    and old.is_active = true
    and (new.role <> 'admin' or new.is_active = false)
    and not public.album_has_other_admin(old.album_id, old.user_id) then
    raise exception 'An album needs at least one Admin.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_last_album_admin_removal
on public.album_members;

create trigger prevent_last_album_admin_removal
before update on public.album_members
for each row execute function public.prevent_last_album_admin_removal();
