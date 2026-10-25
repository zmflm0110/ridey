import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { parseStaffProfile, staffAccess, staffRedirect } from "@/lib/auth/access";
import { demoMode } from "@/lib/demo";
import { supabaseEnv } from "@/lib/supabase/env";

async function readAccess(request: NextRequest, response: NextResponse) {
  const env = supabaseEnv();
  if (!env) return { access: staffAccess(null, null), response };
  const supabase = createServerClient(env.url, env.key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return { access: staffAccess(null, null), response };
  const me = await supabase.rpc("staff_me");
  return {
    access: staffAccess(data.user, parseStaffProfile(me.data)),
    response,
  };
}

function redirectTo(request: NextRequest, response: NextResponse, pathname: string) {
  const url = request.nextUrl.clone();
  url.pathname = pathname;
  const redirect = NextResponse.redirect(url);
  response.cookies.getAll().forEach((cookie) => {
    redirect.cookies.set(cookie);
  });
  return redirect;
}

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  if (demoMode()) {
    // 둘러보기: 로그인 화면 없이 바로 운영 화면으로. 자료는 RLS 가 공개한 것만 읽힌다.
    const path = request.nextUrl.pathname;
    return path === "/login" || path === "/forbidden" ? redirectTo(request, response, "/overview") : response;
  }
  const { access, response: refreshed } = await readAccess(request, response);
  response = refreshed;
  const target = staffRedirect(access, request.nextUrl.pathname);
  if (target) return redirectTo(request, response, target);
  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|fonts/).*)"],
};
