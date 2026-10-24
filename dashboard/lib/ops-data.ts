import { bikesFrom, type AlarmDay, type CheckedRow } from "@/lib/snapshot";
import { guOf } from "@/lib/stations";
import { createClient } from "@/lib/supabase/server";
import { resolveWorklist } from "@/lib/seoul";
import type { Bike } from "@/lib/priority";

function dayText(value: unknown): string {
  if (typeof value === "string") return value.slice(0, 10);
  return "";
}

export async function loadLive(): Promise<{ at: string | null; body: unknown } | null> {
  const supabase = await createClient();
  if (!supabase) return null;
  const { data, error } = await supabase.from("live_snapshot").select("at, body").limit(1).maybeSingle();
  if (error) throw new Error(error.message);
  return data ? { at: data.at ? String(data.at) : null, body: data.body } : null;
}

export async function loadMorningDays(): Promise<string[]> {
  const supabase = await createClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("ops_lists").select("day").order("day", { ascending: false }).limit(40);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => dayText(row.day)).filter(Boolean);
}

export async function loadMorning(day: string): Promise<Bike[]> {
  const supabase = await createClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("ops_lists").select("body").eq("day", day).maybeSingle();
  if (error) throw new Error(error.message);
  return bikesFrom(data?.body);
}

export async function loadAlarmDays(): Promise<AlarmDay[]> {
  const supabase = await createClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("ops_alarm_days").select("day, scored, hit").order("day");
  if (error) throw new Error(error.message);
  return (data ?? []).flatMap((row) => {
    const day = dayText(row.day);
    if (!day) return [];
    return [{ day, scored: Number(row.scored) || 0, hit: Number(row.hit) || 0 }];
  });
}

export async function loadChecked(): Promise<CheckedRow[]> {
  const supabase = await createClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("checked").select("bike, verdict, n");
  if (error) throw new Error(error.message);
  return (data ?? []).flatMap((row) => {
    if (typeof row.bike !== "string" || typeof row.verdict !== "string") return [];
    return [{ bike: row.bike, verdict: row.verdict, n: Number(row.n) || 0 }];
  });
}

export async function loadInspectionCounts(): Promise<Record<string, number>> {
  const supabase = await createClient();
  if (!supabase) return {};
  const { data, error } = await supabase.from("field_records").select("station");
  if (error) throw new Error(error.message);
  const counts: Record<string, number> = {};
  for (const row of data ?? []) {
    if (!row.station) continue;
    const gu = guOf(String(row.station));
    counts[gu] = (counts[gu] ?? 0) + 1;
  }
  return counts;
}

export async function loadScore(day: string): Promise<{ listed: number; rode: number; firstDud: number } | null> {
  const supabase = await createClient();
  if (!supabase) return null;
  const { data, error } = await supabase.from("ops_scores").select("listed, rode, first_dud").eq("day", day).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  return { listed: Number(data.listed) || 0, rode: Number(data.rode) || 0, firstDud: Number(data.first_dud) || 0 };
}

export type FieldRecord = {
  id: number;
  at: string;
  station: string | null;
  bike: string;
  status: string;
  note: string | null;
  lat: number | null;
  lon: number | null;
  photo: string | null;
};

export async function loadFieldRecords(): Promise<FieldRecord[]> {
  const supabase = await createClient();
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("field_records")
    .select("id, at, station, bike, status, note, lat, lon, photo")
    .order("at", { ascending: false })
    .limit(200);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: Number(row.id),
    at: String(row.at),
    station: row.station ? String(row.station) : null,
    bike: String(row.bike),
    status: String(row.status),
    note: row.note ? String(row.note) : null,
    lat: row.lat == null ? null : Number(row.lat),
    lon: row.lon == null ? null : Number(row.lon),
    photo: row.photo ? String(row.photo) : null,
  }));
}

export async function signPhotos(names: string[]): Promise<Record<string, string>> {
  const supabase = await createClient();
  if (!supabase) return {};
  const pairs = await Promise.all(names.map(async (name) => {
    const signed = await supabase.storage.from("survey-photos").createSignedUrl(name, 60 * 30);
    return [name, signed.data?.signedUrl ?? ""] as const;
  }));
  return Object.fromEntries(pairs.filter(([, url]) => url));
}

export async function loadWorkBikes(query: { source?: string; day?: string }): Promise<{
  source: "live" | "morning";
  day: string | null;
  days: string[];
  bikes: Bike[];
  at: string | null;
}> {
  const days = await loadMorningDays();
  const choice = resolveWorklist({ days, source: query.source, day: query.day });
  if (choice.source === "morning" && choice.day) {
    return { ...choice, days, bikes: await loadMorning(choice.day), at: null };
  }
  const live = await loadLive();
  return { source: "live", day: null, days, bikes: bikesFrom(live?.body), at: live?.at ?? null };
}
