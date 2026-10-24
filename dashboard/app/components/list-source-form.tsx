export function ListSourceForm({
  source,
  day,
  days,
}: {
  source: "live" | "morning";
  day: string | null;
  days: string[];
}) {
  return (
    <form className="filters">
      <label>
        목록
        <select name="source" defaultValue={source}>
          <option value="live">실시간</option>
          <option value="morning">아침 목록</option>
        </select>
      </label>
      <label>
        아침 날짜
        <select name="day" defaultValue={day ?? days[0] ?? ""}>
          {days.length ? days.map((item) => <option key={item}>{item}</option>) : <option value="">없음</option>}
        </select>
      </label>
      <button type="submit">보기</button>
    </form>
  );
}
