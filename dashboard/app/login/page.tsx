import { LoginForm } from "@/app/login/login-form";

export default function LoginPage() {
  return (
    <main className="gate">
      <p className="wordmark">
        RIDEY<i />
      </p>
      <h1>로그인</h1>
      <p>초대받은 직원 계정으로 들어와요.</p>
      <LoginForm />
    </main>
  );
}
