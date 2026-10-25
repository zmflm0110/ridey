import type { StaffProfile } from "@/lib/auth/access";

/**
 * 로그인 없이 보는 둘러보기(심사·시연용). 서버 환경 변수 RIDEY_DEMO=1 일 때만 켜진다.
 * publishable 키로 읽으므로 보이는 것은 RLS 가 이미 공개한 뷰뿐이고, 현장 판정은 저장하지 않는다.
 */
export function demoMode(): boolean {
  return process.env.RIDEY_DEMO === "1";
}

export const demoProfile: StaffProfile = { email: "둘러보기", role: "staff", districts: [], active: true };
