import { ListSourceForm } from "@/app/components/list-source-form";
import { loadInspectionCounts, loadWorkBikes } from "@/lib/ops-data";
import { districtRows } from "@/lib/snapshot";
import { guOf } from "@/lib/stations";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ source?: string; day?: string }>;
}) {
  const query = await searchParams;
  let problem: string | null = null;
  let work: Awaited<ReturnType<typeof loadWorkBikes>> | null = null;
  let rows: ReturnType<typeof districtRows> = [];
  let inspected = true;
  try {
    // 점검 기록은 직원만 읽는다 — 못 읽으면 그 열만 '–' 로 두고 나머지는 보여 준다.
    const [loaded, inspections] = await Promise.all([
      loadWorkBikes(query),
      loadInspectionCounts().catch(() => null),
    ]);
    work = loaded;
    inspected = inspections != null;
    rows = districtRows(loaded.bikes, (bike) => guOf(bike.station), inspections ?? {});
  } catch {
    problem = "자치구 현황을 읽지 못했어요.";
  }
  return (
    <section className="stack">
      <h1>자치구</h1>
      <p>구별 의심 대수, 강한 경보, 모델 기대값, 지금까지의 점검 기록이에요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      {work ? <ListSourceForm source={work.source} day={work.day} days={work.days} /> : null}
      {work && !inspected ? <p className="hint">점검 수는 직원으로 로그인하면 보여요.</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>자치구</th><th>대수</th><th>강한 경보</th><th>기대값</th><th>점검</th></tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.gu}>
                <td>{row.gu}</td>
                <td>{row.bikes}</td>
                <td>{row.red}</td>
                <td>{row.expected == null ? "–" : row.expected.toFixed(1)}</td>
                <td>{inspected ? row.inspections : "–"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
