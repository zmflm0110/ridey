"""ops.staff 명단, 가입 연결, 비활성화, developer 보호. 기존 쓰기 정책은 아직 그대로다.

    PG_TEST_DSN="host=localhost port=5432 user=postgres password=postgres" python -m pytest -q tests/test_staff_rls.py
"""
import os, pathlib, subprocess
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
DSN = os.environ.get("PG_TEST_DSN")
pytestmark = pytest.mark.skipif(not DSN, reason="PG_TEST_DSN 이 있을 때만")
DB = "ridey_staff_rls"

DEV = "11111111-1111-1111-1111-111111111111"
ADMIN = "22222222-2222-2222-2222-222222222222"
STAFF = "33333333-3333-3333-3333-333333333333"
PAUSED = "44444444-4444-4444-4444-444444444444"
OUTSIDER = "55555555-5555-5555-5555-555555555555"

STUBS = """
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  email text
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text,
  public boolean,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table if not exists storage.objects (
  id bigint generated always as identity primary key,
  bucket_id text,
  name text
);
alter table storage.objects enable row level security;
"""


def psql(sql, db=DB, ok=True):
    result = subprocess.run(
        ["psql", f"{DSN} dbname={db}", "-X", "-At", "-q", "-v", "ON_ERROR_STOP=1"],
        input=sql,
        capture_output=True,
        text=True,
    )
    if ok:
        assert result.returncode == 0, result.stderr[-2000:]
    return result


def as_user(uid, role, sql, ok=True):
    claim = uid or ""
    return psql(
        f"set request.jwt.claim.sub to '{claim}';\nset role {role};\n{sql}",
        ok=ok,
    )


@pytest.fixture(scope="module")
def database():
    psql(f"drop database if exists {DB} with (force)", "postgres")
    psql(f"create database {DB}", "postgres")
    psql(STUBS)
    psql((ROOT / "supabase" / "schema.sql").read_text())
    staff = (ROOT / "supabase" / "staff.sql").read_text()
    psql(staff)
    psql(staff)
    yield
    psql("reset role")
    psql(f"drop database if exists {DB} with (force)", "postgres")


def test_links_staff_by_email_before_or_after_signup(database):
    psql("""
      insert into ops.staff (email, role) values ('Dev@Example.com', 'developer');
      insert into ops.staff (email, role, districts) values ('ADMIN@example.com', 'admin', '{강남구}');
      insert into auth.users (id, email) values
        ('11111111-1111-1111-1111-111111111111', 'dev@example.com'),
        ('22222222-2222-2222-2222-222222222222', 'admin@example.com'),
        ('55555555-5555-5555-5555-555555555555', 'outsider@example.com');
      insert into auth.users (id, email) values
        ('33333333-3333-3333-3333-333333333333', 'staff@example.com'),
        ('44444444-4444-4444-4444-444444444444', 'paused@example.com');
      insert into ops.staff (email, role, districts) values
        ('staff@example.com', 'staff', '{마포구}'),
        ('paused@example.com', 'staff', '{종로구}');
      update ops.staff set active = false where email = 'paused@example.com';
    """.replace("11111111-1111-1111-1111-111111111111", DEV)
       .replace("22222222-2222-2222-2222-222222222222", ADMIN)
       .replace("33333333-3333-3333-3333-333333333333", STAFF)
       .replace("44444444-4444-4444-4444-444444444444", PAUSED)
       .replace("55555555-5555-5555-5555-555555555555", OUTSIDER))

    linked = psql(
        "select email || ' ' || user_id::text || ' ' || role || ' ' || active::text "
        "|| ' ' || coalesce(array_to_string(districts, ','), '') "
        "from ops.staff order by email"
    ).stdout.strip().splitlines()
    assert linked == [
        f"admin@example.com {ADMIN} admin true 강남구",
        f"dev@example.com {DEV} developer true ",
        f"paused@example.com {PAUSED} staff false 종로구",
        f"staff@example.com {STAFF} staff true 마포구",
    ]


def test_staff_me_follows_the_active_allowlist(database):
    assert "developer" in as_user(DEV, "authenticated", "select public.staff_me();").stdout
    assert "마포구" in as_user(STAFF, "authenticated", "select public.staff_me();").stdout
    assert as_user(PAUSED, "authenticated", "select public.staff_me();").stdout.strip() == ""
    assert as_user(OUTSIDER, "authenticated", "select public.staff_me();").stdout.strip() == ""
    denied = as_user(None, "anon", "select public.staff_me();", ok=False)
    assert denied.returncode != 0


def test_only_admin_or_developer_can_change_the_allowlist(database):
    denied = as_user(STAFF, "authenticated", "select public.staff_list();", ok=False)
    assert denied.returncode != 0
    listed = as_user(ADMIN, "authenticated", "select email from public.staff_list();").stdout
    assert "dev@example.com" in listed and "staff@example.com" in listed

    cannot = as_user(
        STAFF, "authenticated",
        "select public.staff_set_active('paused@example.com', true);",
        ok=False,
    )
    assert cannot.returncode != 0

    as_user(ADMIN, "authenticated", "select public.staff_set_active('staff@example.com', false);")
    assert as_user(STAFF, "authenticated", "select public.staff_me();").stdout.strip() == ""
    assert psql(
        f"set request.jwt.claim.sub to '{STAFF}'; select ops.is_staff();"
    ).stdout.strip() == "f"

    protected = as_user(
        ADMIN, "authenticated",
        "select public.staff_set_active('dev@example.com', false);",
        ok=False,
    )
    assert protected.returncode != 0
    assert "developer" in as_user(DEV, "authenticated", "select public.staff_me();").stdout

    as_user(DEV, "authenticated", "select public.staff_set_active('staff@example.com', true);")
    assert "staff" in as_user(STAFF, "authenticated", "select public.staff_me();").stdout
