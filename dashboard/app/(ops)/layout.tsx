import { OperationsShell } from "@/app/components/operations-shell";
import { requireStaff } from "@/lib/auth/requireStaff";

export default async function OpsLayout({ children }: { children: React.ReactNode }) {
  await requireStaff();
  return <OperationsShell>{children}</OperationsShell>;
}
