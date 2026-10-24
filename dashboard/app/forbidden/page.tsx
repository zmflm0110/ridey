import { LogoutButton } from "@/app/components/logout-button";

export default function ForbiddenPage() {
  return (
    <main className="gate">
      <h1>권한이 없어요</h1>
      <p>이 계정은 직원 명단에 없어요.</p>
      <LogoutButton />
    </main>
  );
}
