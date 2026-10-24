import { expectOf, type Bike, type Checked } from "@/lib/priority";
import { minutesAgo } from "@/lib/seoul";

export type SnapshotBody = {
  at?: string;
  bikes?: Bike[];
  today_alarms?: number;
  model?: { q?: number; expected?: number; at_least?: number };
  feed?: { ok?: boolean; since?: string; ratio?: number };
  score?: { scored?: number; next_rider_dud?: number };
};

export type LiveSummary = {
  bikes: Bike[];
  red: number;
  todayAlarms: number | null;
  expected: number | null;
  atLeast: number | null;
  minutesOld: number | null;
  stale: boolean;
  feed: { sinceHour: number; ratio: number } | null;
  score: { scored: number; hit: number } | null;
};

export type AlarmDay = { day: string; scored: number; hit: number };
export type AlarmBar = { day: string; label: string; pct: number; height: number };

export type CheckedRow = { bike: string; verdict: string; n: number };
export type CheckedDetail = Checked & { verdicts: { verdict: string; n: number }[] };

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

export function bikesFrom(body: unknown): Bike[] {
  if (!body || typeof body !== "object" || !Array.isArray((body as SnapshotBody).bikes)) return [];
  return (body as SnapshotBody).bikes!.flatMap((row) => {
    if (!row || typeof row.bike !== "string" || typeof row.station !== "string") return [];
    return [
      {
        ...row,
        station_name: String(row.station_name ?? row.station).trim(),
        chain: Number(row.chain) || 0,
        level: String(row.level ?? ""),
      },
    ];
  });
}

export function summarizeLive(body: unknown, at: string | null, now = Date.now()): LiveSummary {
  const bikes = bikesFrom(body);
  const raw = body && typeof body === "object" ? (body as SnapshotBody) : {};
  const stamp = at || raw.at || null;
  const age = stamp ? minutesAgo(stamp, now) : null;
  const feed = raw.feed && raw.feed.ok === false && typeof raw.feed.since === "string" && typeof raw.feed.ratio === "number"
    ? { sinceHour: Number(raw.feed.since.slice(11, 13)) || 0, ratio: raw.feed.ratio }
    : null;
  const scored = numberOrNull(raw.score?.scored);
  const hit = numberOrNull(raw.score?.next_rider_dud);
  return {
    bikes,
    red: bikes.filter((bike) => bike.level === "빨강").length,
    todayAlarms: numberOrNull(raw.today_alarms),
    expected: numberOrNull(raw.model?.expected),
    atLeast: numberOrNull(raw.model?.at_least),
    minutesOld: age,
    stale: age != null && age > 30,
    feed,
    score: scored != null && hit != null && scored >= 20 ? { scored, hit } : null,
  };
}

export function alarmBars(days: AlarmDay[]): AlarmBar[] | null {
  const ready = days.filter((day) => day.scored >= 100);
  if (ready.length < 3) return null;
  return ready.map((day) => {
    const pct = (100 * day.hit) / day.scored;
    const [, month, date] = day.day.split("-").map(Number);
    return { day: day.day, label: `${month}/${date}`, pct, height: Math.min(100, pct * 2) };
  });
}

export function indexChecked(rows: CheckedRow[]): Record<string, CheckedDetail> {
  const out: Record<string, CheckedDetail> = {};
  for (const row of rows) {
    const current = out[row.bike] ?? { total: 0, broken: 0, verdicts: [] };
    current.total += row.n;
    if (row.verdict !== "멀쩡함") current.broken += row.n;
    current.verdicts.push({ verdict: row.verdict, n: row.n });
    out[row.bike] = current;
  }
  return out;
}

export function checkedCounts(details: Record<string, CheckedDetail>): Record<string, Checked> {
  return Object.fromEntries(Object.entries(details).map(([bike, detail]) => [bike, { total: detail.total, broken: detail.broken }]));
}

export type DistrictRow = {
  gu: string;
  bikes: number;
  red: number;
  expected: number | null;
  inspections: number;
};

export function districtRows(
  bikes: Bike[],
  guOf: (bike: Bike) => string,
  inspections: Record<string, number>,
): DistrictRow[] {
  const groups = new Map<string, Bike[]>();
  for (const bike of bikes) {
    const gu = guOf(bike) || "기타";
    groups.set(gu, [...(groups.get(gu) ?? []), bike]);
  }
  return [...groups.entries()]
    .map(([gu, rows]) => ({
      gu,
      bikes: rows.length,
      red: rows.filter((bike) => bike.level === "빨강").length,
      expected: expectOf(rows),
      inspections: inspections[gu] ?? 0,
    }))
    .sort((a, b) => b.bikes - a.bikes || a.gu.localeCompare(b.gu, "ko"));
}
