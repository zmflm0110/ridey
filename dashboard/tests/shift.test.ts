import { describe, expect, it } from "vitest";
import { morningCsv, morningFilename, routeCsv } from "../lib/csv";
import { planShift } from "../lib/shift";
import type { Station } from "../lib/stations";
import type { Bike } from "../lib/priority";

const station = (partial: Station): Station => partial;
const bike = (partial: Partial<Bike> & Pick<Bike, "bike" | "station">): Bike => ({
  station_name: partial.station,
  chain: 2,
  level: "노랑",
  ...partial,
});

describe("shift plan", () => {
  const stations = new Map<string, Station>([
    ["00001", station({ id: "00001", name: "가까운 곳", gu: "마포구", lat: 37.5, lon: 127 })],
    ["00002", station({ id: "00002", name: "먼 곳", gu: "마포구", lat: 37.55, lon: 127.08 })],
  ]);

  it("stays inside the shift and drops a stop that does not fit", () => {
    const bikes = [
      bike({ bike: "SPB-00001", station: "00001" }),
      bike({ bike: "SPB-00002", station: "00002", chain: 4, level: "빨강" }),
    ];
    const start = stations.get("00001")!;
    const fitted = planShift({ bikes, stations, routeValue: null, busy: null, minutes: 180, t0: 9 * 60, start });
    expect(fitted.used).toBeLessThanOrEqual(180);
    expect(fitted.stops.length).toBeGreaterThan(0);
    const tight = planShift({ bikes, stations, routeValue: null, busy: null, minutes: 5, t0: 9 * 60, start });
    expect(tight.stops).toEqual([]);
  });

  it("writes a quoted route csv with a BOM", () => {
    const csv = routeCsv([{ order: 1, arrival: "09:10", gu: "마포구", id: "00001", name: '가까운 "곳"', bikes: 2, people: "1.2명" }]);
    expect(csv.startsWith("\ufeff")).toBe(true);
    expect(csv).toContain('"가까운 ""곳"');
    expect(csv).toContain("\r\n");
  });

  it("matches the web morning list columns", () => {
    const csv = morningCsv({
      day: "2026-10-25",
      bikes: [{ bike: "SPB-00001", station: "00001", station_name: '가까운 "곳"', chain: 3, level: "빨강", last_dud: "10-25 09:00", reported: false }],
      guOf: () => "마포구",
      checked: { "SPB-00001": { total: 2, broken: 1 } },
    });
    const lines = csv.replace(/^\ufeff/, "").trim().split("\r\n");
    expect(lines[0]).toBe('"기준일","구","대여소번호","대여소","자전거번호","서로 다른 사람 연속 헛대여(명)","단계","마지막 헛대여","고장 신고","사람 확인(구조대·현장 조사)"');
    expect(lines[1]).toContain('"없음"');
    expect(lines[1]).toContain('"고장 1/2"');
    expect(lines[1]).toContain('"가까운 ""곳"');
    expect(morningFilename("2026-10-25", "마포구")).toBe("morning_2026-10-25_mapo.csv");
  });
});
