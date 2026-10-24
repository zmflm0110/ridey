"use client";

import { createClient } from "@/lib/supabase/client";

export function LogoutButton() {
  async function logout() {
    const supabase = createClient();
    if (supabase) await supabase.auth.signOut();
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination
    window.location.assign("/login");
  }

  return (
    <button type="button" className="logout" onClick={logout}>
      로그아웃
    </button>
  );
}
