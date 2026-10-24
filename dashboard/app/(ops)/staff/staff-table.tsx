"use client";

import { useActionState } from "react";
import { canDeactivate } from "@/lib/auth/access";

export type StaffRow = {
  email: string;
  role: string;
  districts: string[];
  active: boolean;
  user_id: string | null;
};

export function StaffTable({
  rows,
  action,
}: {
  rows: StaffRow[];
  action: (previous: string | null, formData: FormData) => Promise<string | null>;
}) {
  const [message, formAction, pending] = useActionState(action, null);
  return (
    <div className="stack">
      {message ? <p role="alert">{message}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>이메일</th><th>역할</th><th>담당 구</th><th>상태</th><th></th></tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const turnOff = row.active;
              const blocked = turnOff && !canDeactivate(row.role);
              return (
                <tr key={row.email}>
                  <td>{row.email}{row.user_id ? "" : " · 아직 로그인 안 함"}</td>
                  <td>{row.role}</td>
                  <td>{row.districts.length ? row.districts.join(", ") : "전체"}</td>
                  <td>{row.active ? "활성" : "꺼짐"}</td>
                  <td>
                    <form action={formAction}>
                      <input type="hidden" name="email" value={row.email} />
                      <input type="hidden" name="role" value={row.role} />
                      <input type="hidden" name="active" value={turnOff ? "false" : "true"} />
                      <button type="submit" disabled={pending || blocked}>
                        {blocked ? "끌 수 없음" : turnOff ? "끄기" : "켜기"}
                      </button>
                    </form>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
