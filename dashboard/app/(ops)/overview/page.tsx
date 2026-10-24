import { alarmBars, summarizeLive } from "@/lib/snapshot";
import { loadAlarmDays, loadLive } from "@/lib/ops-data";

export default async function Page() {
  let problem: string | null = null;
  let summary = summarizeLive(null, null);
  let bars: ReturnType<typeof alarmBars> = null;
  try {
    const [live, days] = await Promise.all([loadLive(), loadAlarmDays()]);
    summary = summarizeLive(live?.body, live?.at ?? null);
    bars = alarmBars(days);
  } catch {
    problem = "개요를 읽지 못했어요.";
  }
  const pct = summary.score ? Math.round((100 * summary.score.hit) / summary.score.scored) : null;
  return (
    <section className="stack">
      <h1>개요</h1>
      <p>지금 목록 기준이에요. 출근 전 아침 목록은 우선순위에서 골라요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      <div className="kpis">
        <article><b>{summary.bikes.length}</b><span>고장 의심</span></article>
        <article><b>{summary.red}</b><span>빨강 · 3명 이상</span></article>
        <article><b>{summary.todayAlarms ?? "–"}</b><span>오늘 경보</span></article>
        <article><b>{summary.expected ?? "–"}</b><span>모델이 보는 진짜 고장</span></article>
        <article><b>{summary.atLeast ?? "–"}</b><span>90% 하한</span></article>
      </div>
      {summary.feed ? (
        <p role="status" className="note">
          서울시 대여 기록이 {summary.feed.sinceHour}시부터 평소의 {Math.max(1, Math.round(summary.feed.ratio * 100))}%만 올라오고 있어요. 새 경보가 늦을 수 있어요.
        </p>
      ) : null}
      {summary.stale ? (
        <p role="status" className="note">목록 갱신이 늦어지고 있어요. 마지막 갱신 {summary.minutesOld}분 전이에요.</p>
      ) : null}
      {summary.score && pct != null ? (
        <p>실시간 경보 {summary.score.scored.toLocaleString("ko-KR")}건 중 {summary.score.hit.toLocaleString("ko-KR")}건({pct}%)은 다음 사람도 바로 반납했어요.</p>
      ) : null}
      {bars ? (
        <div className="bars" role="img" aria-label={bars.map((bar) => `${bar.label} ${Math.round(bar.pct)}%`).join(", ")}>
          {bars.map((bar) => (
            <div key={bar.day} className="bar" style={{ ["--h" as string]: `${bar.height}%` }}>
              <i>{Math.round(bar.pct)}</i>
            </div>
          ))}
        </div>
      ) : (
        <p className="hint">채점이 100건 이상인 날이 3일 모이면 날마다 막대로 보여요.</p>
      )}
    </section>
  );
}
