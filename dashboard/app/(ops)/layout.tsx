import { OperationsShell } from "@/app/components/operations-shell";
import { requireStaff } from "@/lib/auth/requireStaff";
import { demoMode } from "@/lib/demo";

export default async function OpsLayout({ children }: { children: React.ReactNode }) {
  await requireStaff();
  return <OperationsShell demo={demoMode()}>{children}</OperationsShell>;
}
