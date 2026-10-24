import { StaffTable, type StaffRow } from "@/app/(ops)/staff/staff-table";
import { setStaffActive } from "@/app/(ops)/staff/actions";
import { canManageStaff } from "@/lib/auth/access";
import { requireStaff } from "@/lib/auth/requireStaff";
import { createClient } from "@/lib/supabase/server";

export default async function Page() {
  const profile = await requireStaff();
  if (!canManageStaff(profile.role)) {
    return (
      <section className="stack">
        <h1>직원</h1>
        <p>직원 명단은 관리자와 개발자만 봐요.</p>
      </section>
    );
  }
  let rows: StaffRow[] = [];
  let problem: string | null = null;
  try {
    const supabase = await createClient();
    if (!supabase) throw new Error("no client");
    const { data, error } = await supabase.rpc("staff_list");
    if (error) throw new Error(error.message);
    rows = (data ?? []).map((row: StaffRow) => ({
      email: row.email,
      role: row.role,
      districts: Array.isArray(row.districts) ? row.districts : [],
      active: row.active === true,
      user_id: row.user_id ?? null,
    }));
  } catch {
    problem = "직원 명단을 읽지 못했어요.";
  }
  return (
    <section className="stack">
      <h1>직원</h1>
      <p>활성과 비활성만 여기서 바꿔요. 새 로그인은 Supabase 대시보드의 Invite user로 만들고, 그 이메일은 데이터베이스 명단에 미리 넣어 둡니다. 이 화면은 secret 키를 쓰지 않아요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      <StaffTable rows={rows} action={setStaffActive} />
    </section>
  );
}
