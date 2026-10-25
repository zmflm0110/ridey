import { CsvButton } from "@/app/components/csv-button";
import { recordsCsv } from "@/lib/csv";
import { demoMode } from "@/lib/demo";
import { loadFieldRecords, signPhotos } from "@/lib/ops-data";
import { seoulStamp } from "@/lib/seoul";
import { stationById } from "@/lib/stations";

export default async function Page() {
  if (demoMode()) {
    return (
      <section className="stack">
        <h1>기록</h1>
        <p>현장 판정의 사진·메모·위치가 모이는 곳이에요. 개인 정보가 들어 있어 직원으로 로그인해야 보여요.</p>
        <p className="info">둘러보기에서는 열리지 않아요. 열은 시각 · 대여소 · 번호 · 판정 · 메모 · 사진(30분짜리 서명 주소)이고, CSV 로 내려받을 수 있어요.</p>
      </section>
    );
  }
  let problem: string | null = null;
  let records: Awaited<ReturnType<typeof loadFieldRecords>> = [];
  let photos: Record<string, string> = {};
  try {
    records = await loadFieldRecords();
    const names = records.flatMap((record) => (record.photo && /^[0-9a-f]{16}\.jpg$/.test(record.photo) ? [record.photo] : []));
    photos = await signPhotos(names);
  } catch {
    problem = "점검 기록을 읽지 못했어요.";
  }
  return (
    <section className="stack">
      <h1>기록</h1>
      <p>최근 200건이에요. 사진은 30분 동안 열리는 주소로 보여요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      <CsvButton label="점검 기록 CSV" filename="field_records.csv" csv={recordsCsv(records)} />
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>시각</th><th>대여소</th><th>번호</th><th>판정</th><th>메모</th><th>사진</th></tr>
          </thead>
          <tbody>
            {records.map((record) => (
              <tr key={record.id}>
                <td>{seoulStamp(record.at)}</td>
                <td>{record.station ? stationById.get(record.station)?.name || record.station : ""}</td>
                <td>{record.bike}</td>
                <td>{record.status}</td>
                <td>{record.note}</td>
                <td>{record.photo && photos[record.photo] ? <a href={photos[record.photo]}>보기</a> : ""}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
