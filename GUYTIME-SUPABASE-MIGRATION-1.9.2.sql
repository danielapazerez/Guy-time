-- Guy Time 1.9.2 — complete repair for family creation and sync.
-- Safe to run more than once. Existing events are preserved.

create extension if not exists pgcrypto;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Guy Time',
  invite_code text not null unique default upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8)),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id),
  unique (user_id)
);

create table if not exists public.events (
  id text primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  event_data jsonb not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.events add column if not exists deleted_at timestamptz;
create index if not exists events_family_id_idx on public.events(family_id);
create index if not exists events_family_updated_idx on public.events(family_id, updated_at desc);
create index if not exists events_family_deleted_idx on public.events(family_id, deleted_at) where deleted_at is not null;

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.events enable row level security;

create or replace function public.is_family_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members fm
    where fm.family_id = fid and fm.user_id = auth.uid()
  );
$$;

-- Remove old policies so this script remains rerunnable.
drop policy if exists "members read family" on public.families;
drop policy if exists "members read memberships" on public.family_members;
drop policy if exists "members read events" on public.events;
drop policy if exists "members insert events" on public.events;
drop policy if exists "members update events" on public.events;
drop policy if exists "members delete events" on public.events;

create policy "members read family" on public.families
for select to authenticated using (public.is_family_member(id));
create policy "members read memberships" on public.family_members
for select to authenticated using (user_id = auth.uid() or public.is_family_member(family_id));
create policy "members read events" on public.events
for select to authenticated using (public.is_family_member(family_id));
create policy "members insert events" on public.events
for insert to authenticated with check (public.is_family_member(family_id));
create policy "members update events" on public.events
for update to authenticated using (public.is_family_member(family_id)) with check (public.is_family_member(family_id));
create policy "members delete events" on public.events
for delete to authenticated using (public.is_family_member(family_id));

create or replace function public.create_family(family_name text default 'Guy Time')
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  fid uuid;
  invite text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select f.id, f.invite_code into fid, invite
  from public.family_members fm
  join public.families f on f.id = fm.family_id
  where fm.user_id = auth.uid()
  limit 1;

  if fid is not null then return invite; end if;

  invite := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8));
  insert into public.families(name, invite_code, created_by)
  values (coalesce(nullif(trim(family_name), ''), 'Guy Time'), invite, auth.uid())
  returning id into fid;

  insert into public.family_members(family_id, user_id, role)
  values (fid, auth.uid(), 'owner');

  return invite;
end;
$$;

create or replace function public.join_family(join_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare fid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from public.family_members where user_id = auth.uid()) then
    raise exception 'already in family';
  end if;
  select id into fid from public.families where invite_code = upper(trim(join_code));
  if fid is null then raise exception 'invalid code'; end if;
  insert into public.family_members(family_id, user_id, role) values(fid, auth.uid(), 'member');
  return fid;
end;
$$;

revoke all on function public.create_family(text) from public;
revoke all on function public.join_family(text) from public;
revoke all on function public.is_family_member(uuid) from public;
grant usage on schema public to authenticated;
grant select on public.families, public.family_members to authenticated;
grant select, insert, update, delete on public.events to authenticated;
grant execute on function public.create_family(text) to authenticated;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.is_family_member(uuid) to authenticated;

alter table public.events replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.events;
exception when duplicate_object then null;
end $$;
