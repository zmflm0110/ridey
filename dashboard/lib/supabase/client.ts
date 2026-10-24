import { createBrowserClient } from "@supabase/ssr";
import { supabaseEnv } from "@/lib/supabase/env";

export function createClient() {
  const env = supabaseEnv();
  if (!env) return null;
  return createBrowserClient(env.url, env.key);
}
