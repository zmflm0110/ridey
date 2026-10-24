import { ListSourceForm } from "@/app/components/list-source-form";
import { PriorityBoard } from "@/app/components/priority-board";
import { requireStaff } from "@/lib/auth/requireStaff";
import { loadChecked, loadWorkBikes } from "@/lib/ops-data";
import { indexChecked } from "@/lib/snapshot";
import { stationById, type Station } from "@/lib/stations";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ source?: string; day?: string }>;
}) {
  const profile = await requireStaff();
  const query = await searchParams;
  let problem: string | null = null;
  let work: Awaited<ReturnType<typeof loadWorkBikes>> | null = null;
  let checked = {};
  try {
    const [loaded, rows] = await Promise.all([loadWorkBikes(query), loadChecked()]);
    work = loaded;
    checked = indexChecked(rows);
  } catch {
    problem = "우선순위 목록을 읽지 못했어요.";
  }
  const stations: Station[] = [];
  const seen = new Set<string>();
  for (const bike of work?.bikes ?? []) {
    if (seen.has(bike.station)) continue;
    const station = stationById.get(bike.station);
    if (!station) continue;
    seen.add(bike.station);
    stations.push(station);
  }
  const when = work?.source === "morning" && work.day ? `${work.day} 아침 목록` : "실시간 목록";
  return (
    <section className="stack">
      <h1>우선순위</h1>
      <p>오전에는 오늘 아침 목록, 낮 12시 이후에는 실시간 목록이 기본이에요. 담당 구가 있으면 그 구부터 보여요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      {work ? (
        <>
          <ListSourceForm source={work.source} day={work.day} days={work.days} />
          <p className="hint">{when}{work.at ? ` · ${work.at}` : ""} · {work.bikes.length}대</p>
          <PriorityBoard bikes={work.bikes} districts={profile.districts} checked={checked} stations={stations} />
        </>
      ) : null}
    </section>
  );
}
