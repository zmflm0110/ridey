export const shellBreakpoints = {
  tabs: 768,
  sidebar: 1280,
} as const;

export type ShellMode = "sidebar" | "collapsible" | "tabs";

/** 1280px 이상은 사이드바, 768–1279px는 접히는 사이드바, 768px 미만은 하단 탭. */
export function shellMode(width: number): ShellMode {
  if (width >= shellBreakpoints.sidebar) return "sidebar";
  if (width >= shellBreakpoints.tabs) return "collapsible";
  return "tabs";
}

export const shellNav = [
  { href: "/overview", label: "개요" },
  { href: "/priority", label: "우선순위" },
  { href: "/districts", label: "자치구" },
  { href: "/route", label: "경로" },
  { href: "/field", label: "현장" },
  { href: "/records", label: "기록" },
  { href: "/lists", label: "목록" },
  { href: "/staff", label: "직원" },
] as const;
