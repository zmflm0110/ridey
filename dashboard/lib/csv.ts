import { groupByStation, type Bike } from "@/lib/priority";

function cell(value: unknown): string {
  return `"${String(value ?? "").replace(/"/g, '""')}"`;
}

export function csvTable(rows: unknown[][]): string {
  return `\ufeff${rows.map((row) => row.map(cell).join(",")).join("\r\n")}\r\n`;
}

const GU_EN: Record<string, string> = {
  강남구: "gangnam", 강동구: "gangdong", 강북구: "gangbuk", 강서구: "gangseo", 관악구: "gwanak", 광진구: "gwangjin",
  구로구: "guro", 금천구: "geumcheon", 노원구: "nowon", 도봉구: "dobong", 동대문구: "dongdaemun", 동작구: "dongjak",
  마포구: "mapo", 서대문구: "seodaemun", 서초구: "seocho", 성동구: "seongdong", 성북구: "seongbuk", 송파구: "songpa",
  양천구: "yangcheon", 영등포구: "yeongdeungpo", 용산구: "yongsan", 은평구: "eunpyeong", 종로구: "jongno", 중구: "jung",
  중랑구: "jungnang",
};

export function morningFilename(day: string, gu = ""): string {
  if (!gu) return `morning_${day}.csv`;
  return `morning_${day}_${GU_EN[gu] || "gu"}.csv`;
}

export function morningCsv(input: {
  day: string;
  bikes: Bike[];
  guOf: (station: string) => string;
  checked: Record<string, { total: number; broken: number }>;
}): string {
  const rows = groupByStation(input.bikes, input.checked).flatMap(([, bikes]) => bikes).map((bike) => {
    const checked = input.checked[bike.bike];
    return [
      input.day,
      input.guOf(bike.station),
      bike.station,
      bike.station_name,
      bike.bike,
      bike.chain,
      bike.level,
      bike.last_dud ?? "",
      bike.reported === true ? "있음" : bike.reported === false ? "없음" : "모름",
      checked?.total ? `고장 ${checked.broken}/${checked.total}` : "",
    ];
  });
  return csvTable([
    ["기준일", "구", "대여소번호", "대여소", "자전거번호", "서로 다른 사람 연속 헛대여(명)", "단계", "마지막 헛대여", "고장 신고", "사람 확인(구조대·현장 조사)"],
    ...rows,
  ]);
}

export function recordsCsv(rows: {
  at: string;
  station: string | null;
  bike: string;
  status: string;
  note: string | null;
  lat: number | null;
  lon: number | null;
  photo: string | null;
}[]): string {
  return csvTable([
    ["본 시각", "대여소번호", "자전거번호", "판정", "메모", "위도", "경도", "사진"],
    ...rows.map((row) => [row.at, row.station ?? "", row.bike, row.status, row.note ?? "", row.lat ?? "", row.lon ?? "", row.photo ?? ""]),
  ]);
}

export function routeCsv(
  rows: { order: number; arrival: string; gu: string; id: string; name: string; bikes: number; people: string }[],
): string {
  return csvTable([
    ["순서", "도착", "구", "대여소번호", "대여소", "의심 대수", "막을 헛걸음"],
    ...rows.map((row) => [row.order, row.arrival, row.gu, row.id, row.name, row.bikes, row.people]),
  ]);
}
