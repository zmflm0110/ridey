import { OperationsShell } from "@/app/components/operations-shell";

export default function OpsLayout({ children }: { children: React.ReactNode }) {
  return <OperationsShell>{children}</OperationsShell>;
}
