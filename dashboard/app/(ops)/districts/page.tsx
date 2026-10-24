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
  try {
    const [loaded, inspections] = await Promise.all([loadWorkBikes(query), loadInspectionCounts()]);
    work = loaded;
    rows = districtRows(loaded.bikes, (bike) => guOf(bike.station), inspections);
  } catch {
    problem = "자치구 현황을 읽지 못했어요.";
  }
  return (
    <section className="stack">
      <h1>자치구</h1>
      <p>구별 의심 대수, 빨강, 모델 기대값, 지금까지의 점검 기록이에요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      {work ? <ListSourceForm source={work.source} day={work.day} days={work.days} /> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>자치구</th><th>대수</th><th>빨강</th><th>기대값</th><th>점검</th></tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.gu}>
                <td>{row.gu}</td>
                <td>{row.bikes}</td>
                <td>{row.red}</td>
                <td>{row.expected == null ? "–" : row.expected.toFixed(1)}</td>
                <td>{row.inspections}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
