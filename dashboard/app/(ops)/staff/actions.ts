"use server";

import { revalidatePath } from "next/cache";
import { canDeactivate, canManageStaff } from "@/lib/auth/access";
import { requireStaff } from "@/lib/auth/requireStaff";
import { createClient } from "@/lib/supabase/server";

export async function setStaffActive(_previous: string | null, formData: FormData): Promise<string | null> {
  const profile = await requireStaff();
  if (!canManageStaff(profile.role)) return "직원 명단을 바꿀 권한이 없어요.";
  const email = String(formData.get("email") || "").trim().toLowerCase();
  const active = formData.get("active") === "true";
  if (!active && !canDeactivate(String(formData.get("role") || ""))) return "developer 계정은 비활성화할 수 없어요.";
  const supabase = await createClient();
  if (!supabase || !email) return "명단을 바꾸지 못했어요.";
  const { error } = await supabase.rpc("staff_set_active", { target_email: email, next_active: active });
  if (error) return error.message;
  revalidatePath("/staff");
  return null;
}
