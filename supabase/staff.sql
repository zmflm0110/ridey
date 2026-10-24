-- RIDEY 직원 명단. 기존 rescue·survey 정책은 여기서 바꾸지 않는다.
-- 적용: schema.sql 다음, 분석 SQL(model·live·ev·calib) 전. 여러 번 돌려도 된다.
-- ops 스키마는 PostgREST 에 노출하지 않는다. 앱이 부르는 함수만 public RPC 다.
-- 개발자 등록은 staff_seed.example.sql (실제 이메일은 커밋하지 않는다).

create schema if not exists ops;
comment on schema ops is '직원 명단. PostgREST exposed schemas 에 넣지 않는다.';

create table if not exists ops.staff (
  email      text primary key,
  user_id    uuid unique,
  role       text not null check (role in ('staff', 'admin', 'developer')),
  districts  text[] not null default '{}',
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists staff_user_id on ops.staff (user_id);

-- 이메일은 소문자로 두고, 이미 가입한 계정이면 user_id 를 바로 잇는다.
-- developer 는 구 제한이 없다.
create or replace function ops.normalize_staff() returns trigger
language plpgsql security definer set search_path = ops, auth, public as $$
begin
  new.email := lower(btrim(new.email));
  if new.role = 'developer' then
    new.districts := '{}';
  end if;
  if new.user_id is null then
    select id into new.user_id from auth.users where lower(email) = new.email limit 1;
  end if;
  return new;
end $$;

drop trigger if exists normalize_staff on ops.staff;
create trigger normalize_staff before insert or update of email, role on ops.staff
  for each row execute function ops.normalize_staff();

-- 초대받은 사람이 처음 가입하면 이메일로 명단 행에 계정을 붙인다.
create or replace function ops.link_staff_user() returns trigger
language plpgsql security definer set search_path = ops, auth, public as $$
begin
  if new.email is not null then
    update ops.staff
       set user_id = new.id
     where email = lower(new.email)
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end $$;

drop trigger if exists link_staff_user on auth.users;
create trigger link_staff_user after insert on auth.users
  for each row execute function ops.link_staff_user();

create or replace function ops.has_role(needed text[]) returns boolean
language sql stable security definer set search_path = ops, public as $$
  select exists (
    select 1 from ops.staff
    where user_id = auth.uid() and active and role = any(needed)
  );
$$;

create or replace function ops.is_staff() returns boolean
language sql stable security definer set search_path = ops, public as $$
  select ops.has_role(array['staff', 'admin', 'developer']);
$$;

create or replace function public.staff_me() returns jsonb
language sql stable security definer set search_path = ops, public as $$
  select jsonb_build_object(
    'email', email,
    'role', role,
    'districts', to_jsonb(districts),
    'active', active
  )
  from ops.staff
  where user_id = auth.uid() and active;
$$;

create or replace function public.staff_list()
returns table (email text, role text, districts text[], active boolean, user_id uuid)
language plpgsql stable security definer set search_path = ops, public as $$
begin
  if not ops.has_role(array['admin', 'developer']) then
    raise exception '직원 명단을 볼 권한이 없어요' using errcode = '42501';
  end if;
  return query
    select s.email, s.role, s.districts, s.active, s.user_id
    from ops.staff s
    order by s.email;
end $$;

-- admin 과 developer 만 활성 여부를 바꾼다. developer 행은 끌 수 없다.
create or replace function public.staff_set_active(target_email text, next_active boolean)
returns void
language plpgsql security definer set search_path = ops, public as $$
declare target_role text;
begin
  if not ops.has_role(array['admin', 'developer']) then
    raise exception '직원 명단을 바꿀 권한이 없어요' using errcode = '42501';
  end if;
  select role into target_role from ops.staff where email = lower(btrim(target_email));
  if target_role is null then
    raise exception '명단에 없는 이메일이에요' using errcode = 'P0002';
  end if;
  if target_role = 'developer' and next_active is false then
    raise exception 'developer 계정은 비활성화할 수 없어요' using errcode = '42501';
  end if;
  update ops.staff set active = next_active where email = lower(btrim(target_email));
end $$;

revoke all on schema ops from public, anon, authenticated;
revoke all on all tables in schema ops from public, anon, authenticated;
revoke all on function ops.normalize_staff() from public;
revoke all on function ops.link_staff_user() from public;
revoke all on function ops.has_role(text[]) from public;
revoke all on function ops.is_staff() from public;
revoke all on function public.staff_me() from public;
revoke all on function public.staff_list() from public;
revoke all on function public.staff_set_active(text, boolean) from public;
grant execute on function public.staff_me() to authenticated;
grant execute on function public.staff_list() to authenticated;
grant execute on function public.staff_set_active(text, boolean) to authenticated;
