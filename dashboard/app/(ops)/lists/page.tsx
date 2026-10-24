import { CsvButton } from "@/app/components/csv-button";
import { morningCsv, morningFilename } from "@/lib/csv";
import { loadChecked, loadMorning, loadMorningDays, loadScore } from "@/lib/ops-data";
import { checkedCounts, indexChecked } from "@/lib/snapshot";
import { guOf, stationById } from "@/lib/stations";
import { groupByStation } from "@/lib/priority";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ day?: string }>;
}) {
  const query = await searchParams;
  let problem: string | null = null;
  let days: string[] = [];
  let day = "";
  let bikes: Awaited<ReturnType<typeof loadMorning>> = [];
  let score: Awaited<ReturnType<typeof loadScore>> = null;
  let checked = {};
  try {
    days = await loadMorningDays();
    day = query.day && days.includes(query.day) ? query.day : days[0] ?? "";
    if (day) {
      const [loaded, scoreRow, checks] = await Promise.all([loadMorning(day), loadScore(day), loadChecked()]);
      bikes = loaded;
      score = scoreRow;
      checked = checkedCounts(indexChecked(checks));
    }
  } catch {
    problem = "아침 목록을 읽지 못했어요.";
  }
  const groups = groupByStation(bikes, checked);
  const pct = score && score.rode ? Math.round((100 * score.firstDud) / score.rode) : null;
  return (
    <section className="stack">
      <h1>목록</h1>
      <p>06:10에 만들어진 아침 목록과 다음 날 채점이에요. CSV는 웹앱과 같은 열이에요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      <form className="filters">
        <label>
          날짜
          <select name="day" defaultValue={day}>
            {days.map((item) => <option key={item}>{item}</option>)}
          </select>
        </label>
        <button type="submit">보기</button>
      </form>
      {score ? (
        <p>목록 {score.listed}대 중 다음 날 탄 사람 {score.rode}명, 또 바로 반납 {score.firstDud}명{pct != null ? ` (${pct}%)` : ""}.</p>
      ) : <p className="hint">이 날짜의 채점이 아직 없어요.</p>}
      {day ? (
        <CsvButton
          label="아침 목록 CSV"
          filename={morningFilename(day)}
          csv={morningCsv({ day, bikes, guOf, checked })}
        />
      ) : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>대여소</th><th>구</th><th>번호</th><th>단계</th><th>연속</th></tr>
          </thead>
          <tbody>
            {groups.flatMap(([id, rows]) => rows.map((bike) => (
              <tr key={bike.bike}>
                <td>{stationById.get(id)?.name || bike.station_name}</td>
                <td>{guOf(id)}</td>
                <td>{bike.bike}</td>
                <td>{bike.level}</td>
                <td>{bike.chain}</td>
              </tr>
            )))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
