-- 개발자 한 명을 ops.staff 에 넣는다. 실제 이메일은 이 파일에 적지 않는다.
--   psql "$SUPABASE_DB" -v developer_email=you@example.com -f supabase/staff_seed.example.sql
-- 명단이 잘못돼도 DB 비밀번호로 이 파일을 다시 실행하면 developer 로 복구된다.

insert into ops.staff (email, role, districts, active)
values (lower(:'developer_email'), 'developer', '{}', true)
on conflict (email) do update
  set role = 'developer', active = true, districts = '{}';
