"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const supabase = createClient();
    if (!supabase) {
      setMessage("로그인 설정이 아직 없어요.");
      return;
    }
    setPending(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setPending(false);
    if (error) {
      setMessage("이메일 또는 비밀번호를 확인해 주세요.");
      return;
    }
    // A full load lets the proxy read the session cookie before any ops page renders.
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination
    window.location.assign("/overview");
  }

  return (
    <form className="login-form" onSubmit={onSubmit}>
      <label>
        이메일
        <input
          type="email"
          name="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
        />
      </label>
      <label>
        비밀번호
        <input
          type="password"
          name="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
      </label>
      <button type="submit" disabled={pending}>
        로그인
      </button>
      {message ? <p role="alert">{message}</p> : null}
    </form>
  );
}
