-- Guy Time 1.9.4 — family join/leave repair.
-- מריצים את הקובץ הזה ב-Supabase (SQL Editor) פעם אחת. בטוח להריץ שוב. אירועים קיימים נשמרים.
--
-- מה הקובץ מתקן:
-- 1. join_family: מי שיצר בטעות משפחה משלו (והוא היחיד בה) יועבר אוטומטית למשפחה שהוא מצטרף אליה.
-- 2. leave_family (חדש): מאפשר לעזוב משפחה כדי להצטרף לאחרת.
-- 3. יצירת קוד הזמנה בלי תלות ב-pgcrypto (extensions.gen_random_bytes נכשל בחלק מהפרויקטים).

-- מחולל קוד הזמנה שלא תלוי בהרחבות.
create or replace function public.gt_invite_code()
returns text
language sql
volatile
as $$
  select upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
$$;

alter table public.families alter column invite_code set default public.gt_invite_code();

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

  invite := public.gt_invite_code();
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
declare
  fid uuid;
  cur uuid;
  member_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select id into fid from public.families where invite_code = upper(trim(join_code));
  if fid is null then raise exception 'invalid code'; end if;

  select family_id into cur from public.family_members where user_id = auth.uid();
  if cur is not null then
    if cur = fid then return fid; end if;
    select count(*) into member_count from public.family_members where family_id = cur;
    -- אם המשתמש לבד במשפחה שלו (נוצרה בטעות) — עוזבים אותה אוטומטית ומצטרפים לחדשה.
    if member_count > 1 then raise exception 'already in family'; end if;
    delete from public.family_members where user_id = auth.uid();
    delete from public.families where id = cur;
  end if;

  insert into public.family_members(family_id, user_id, role) values(fid, auth.uid(), 'member');
  return fid;
end;
$$;

create or replace function public.leave_family()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cur uuid;
  member_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select family_id into cur from public.family_members where user_id = auth.uid();
  if cur is null then return; end if;
  delete from public.family_members where user_id = auth.uid();
  select count(*) into member_count from public.family_members where family_id = cur;
  if member_count = 0 then delete from public.families where id = cur; end if;
end;
$$;

revoke all on function public.create_family(text) from public;
revoke all on function public.join_family(text) from public;
revoke all on function public.leave_family() from public;
grant execute on function public.create_family(text) to authenticated;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.leave_family() to authenticated;
