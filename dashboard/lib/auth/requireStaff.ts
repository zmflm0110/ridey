import { redirect } from "next/navigation";
import { parseStaffProfile, staffAccess, type StaffProfile } from "@/lib/auth/access";
import { demoMode, demoProfile } from "@/lib/demo";
import { createClient } from "@/lib/supabase/server";

export async function readStaffAccess() {
  const supabase = await createClient();
  if (!supabase) return staffAccess(null, null);
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return staffAccess(null, null);
  const me = await supabase.rpc("staff_me");
  return staffAccess(data.user, parseStaffProfile(me.data));
}

export async function requireStaff(): Promise<StaffProfile> {
  if (demoMode()) return demoProfile;
  const access = await readStaffAccess();
  if (access.status === "anonymous") redirect("/login");
  if (access.status === "forbidden") redirect("/forbidden");
  return access.profile;
}
