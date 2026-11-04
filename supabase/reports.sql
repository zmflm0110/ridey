-- 시민 고장 신고(2026-11-04): 이용자가 RIDEY 앱에서 '고장 신고' 를 누르면 여기에 한 줄(자전거 번호·대여소 번호만)이
-- 남고, 앱은 이어서 서울시 공식 신고 화면(bikeseoul.com 고장신고)을 연다. 직원 모드는 최근 72시간 신고 수를 읽어
-- 들를 순서·목록에 '시민 신고 N건' 으로 보여 준다. 개인정보(이름·전화·위치·IP)는 받지 않는다.
-- 적용: psql 로 schema.sql(live.limit_inserts) 다음. 여러 번 돌려도 된다.

create table if not exists public.citizen_reports (
  id         bigint generated always as identity primary key,
  bike       text not null check (bike ~ '^SPB-[0-9]{5,6}$'),
  station    text check (station is null or station ~ '^[0-9]{5}$'),
  created_at timestamptz not null default now()
);
create index if not exists citizen_reports_created on public.citizen_reports (created_at);
create index if not exists citizen_reports_bike on public.citizen_reports (bike);

alter table public.citizen_reports enable row level security;
revoke all on public.citizen_reports from anon, authenticated;
grant insert (bike, station) on public.citizen_reports to anon, authenticated;
drop policy if exists "누구나 신고" on public.citizen_reports;
create policy "누구나 신고" on public.citizen_reports for insert to anon, authenticated with check (true);

-- 장난·도배 막기: 같은 자전거 10분에 3번, 전체 1분에 20번·1시간에 300번(schema.sql 과 같은 규칙).
drop trigger if exists limit_inserts on public.citizen_reports;
create trigger limit_inserts before insert on public.citizen_reports for each row execute function live.limit_inserts();

-- 직원이 읽는 것: 자전거별 최근 72시간 신고 수와 마지막 신고 시각·대여소(줄 하나하나는 안 보여 준다).
create or replace view public.report_counts as
  select bike, count(*)::int as n, max(created_at) as last_at,
         (array_agg(station order by created_at desc) filter (where station is not null))[1] as station
  from public.citizen_reports
  where created_at > now() - interval '72 hours'
  group by bike;
grant select on public.report_counts to anon, authenticated;
