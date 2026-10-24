export type StaffRole = "staff" | "admin" | "developer";

export type StaffProfile = {
  email: string;
  role: StaffRole;
  districts: string[];
  active: boolean;
};

export type StaffAccess =
  | { status: "anonymous" }
  | { status: "forbidden" }
  | { status: "staff"; profile: StaffProfile };

const roles = new Set<StaffRole>(["staff", "admin", "developer"]);

export function parseStaffProfile(value: unknown): StaffProfile | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  if (typeof row.email !== "string" || !roles.has(row.role as StaffRole)) return null;
  const districts = Array.isArray(row.districts)
    ? row.districts.filter((item): item is string => typeof item === "string")
    : [];
  return {
    email: row.email,
    role: row.role as StaffRole,
    districts,
    active: row.active === true,
  };
}

export function staffAccess(
  user: { id: string } | null,
  profile: StaffProfile | null,
): StaffAccess {
  if (!user) return { status: "anonymous" };
  if (!profile?.active) return { status: "forbidden" };
  return { status: "staff", profile };
}

export function staffRedirect(
  access: StaffAccess,
  pathname: string,
): "/login" | "/forbidden" | "/overview" | null {
  if (pathname === "/login") {
    if (access.status === "staff") return "/overview";
    if (access.status === "forbidden") return "/forbidden";
    return null;
  }
  if (pathname === "/forbidden") {
    if (access.status === "anonymous") return "/login";
    if (access.status === "staff") return "/overview";
    return null;
  }
  if (access.status === "anonymous") return "/login";
  if (access.status === "forbidden") return "/forbidden";
  return null;
}
