-- Guy Time 1.9.1 — safe sync migration. Does not delete existing data.
alter table public.events add column if not exists deleted_at timestamptz;
create index if not exists events_family_updated_idx on public.events(family_id, updated_at desc);
create index if not exists events_family_deleted_idx on public.events(family_id, deleted_at) where deleted_at is not null;

-- Ensure Realtime receives enough row information for updates/deletes.
alter table public.events replica identity full;

do $$ begin
  alter publication supabase_realtime add table public.events;
exception when duplicate_object then null;
end $$;
