export function seoulParts(now = new Date()): { date: string; minutes: number } {
  const shifted = new Date(now.getTime() + 9 * 3600_000).toISOString();
  const [date, time] = shifted.split("T");
  const [hour, minute] = time.slice(0, 5).split(":").map(Number);
  return { date, minutes: hour * 60 + minute };
}

export function minutesAgo(at: string, now = Date.now()): number | null {
  const parsed = Date.parse(at.includes("+") || at.endsWith("Z") ? at : `${at}+09:00`);
  if (Number.isNaN(parsed)) return null;
  return Math.max(0, Math.round((now - parsed) / 60_000));
}

/** 낮 12시 전에는 오늘 아침 목록, 그 뒤나 목록이 없으면 실시간. */
export function resolveWorklist(input: {
  now?: Date;
  days: string[];
  source?: string;
  day?: string;
}): { source: "live" | "morning"; day: string | null } {
  const clock = seoulParts(input.now ?? new Date());
  const morningDefault = clock.minutes < 12 * 60 && input.days.includes(clock.date) ? clock.date : null;
  if (input.source === "live") return { source: "live", day: null };
  if (input.source === "morning") {
    if (input.day && input.days.includes(input.day)) return { source: "morning", day: input.day };
    return { source: "morning", day: morningDefault ?? input.days[0] ?? null };
  }
  if (morningDefault) return { source: "morning", day: morningDefault };
  return { source: "live", day: null };
}
