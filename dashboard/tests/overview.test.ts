import { describe, expect, it } from "vitest";
import { resolveWorklist, seoulParts, minutesAgo } from "../lib/seoul";
import { alarmBars, districtRows, indexChecked, summarizeLive, type AlarmDay } from "../lib/snapshot";
import type { Bike } from "../lib/priority";

const bike = (partial: Partial<Bike> & Pick<Bike, "bike" | "station">): Bike => ({
  station_name: partial.station,
  chain: 2,
  level: "노랑",
  ...partial,
});

describe("worklist clock", () => {
  it("uses the Seoul clock and the morning list before noon", () => {
    expect(seoulParts(new Date("2026-10-25T02:30:00Z"))).toEqual({ date: "2026-10-25", minutes: 11 * 60 + 30 });
    const days = ["2026-10-25", "2026-10-24"];
    expect(resolveWorklist({ now: new Date("2026-10-25T02:30:00Z"), days })).toEqual({
      source: "morning",
      day: "2026-10-25",
    });
    expect(resolveWorklist({ now: new Date("2026-10-25T03:00:00Z"), days })).toEqual({ source: "live", day: null });
    expect(resolveWorklist({ now: new Date("2026-10-25T01:00:00Z"), days: ["2026-10-24"], source: "morning" })).toEqual({
      source: "morning",
      day: "2026-10-24",
    });
  });

  it("reads a Seoul timestamp without a zone as KST", () => {
    expect(minutesAgo("2026-10-25T11:00:00", Date.parse("2026-10-25T02:30:00Z"))).toBe(30);
  });
});

describe("live summary", () => {
  const body = {
    at: "2026-10-25T11:00:00",
    today_alarms: 12,
    model: { expected: 4.2, at_least: 2 },
    feed: { ok: false, since: "2026-10-25T09:00:00", ratio: 0.4 },
    score: { scored: 20, next_rider_dud: 7 },
    bikes: [bike({ bike: "SPB-00001", station: "1", level: "빨강", chain: 3 }), bike({ bike: "SPB-00002", station: "1" })],
  };

  it("counts suspects, red bikes, model bounds, a late feed, and a score", () => {
    const summary = summarizeLive(body, "2026-10-25T11:00:00", Date.parse("2026-10-25T02:40:00Z"));
    expect(summary.bikes).toHaveLength(2);
    expect(summary.red).toBe(1);
    expect(summary.todayAlarms).toBe(12);
    expect(summary.expected).toBe(4.2);
    expect(summary.atLeast).toBe(2);
    expect(summary.stale).toBe(true);
    expect(summary.feed).toEqual({ sinceHour: 9, ratio: 0.4 });
    expect(summary.score).toEqual({ scored: 20, hit: 7 });
  });

  it("draws alarm bars only after three days with 100 scored alarms", () => {
    const days: AlarmDay[] = [
      { day: "2026-10-01", scored: 100, hit: 25 },
      { day: "2026-10-02", scored: 80, hit: 20 },
      { day: "2026-10-03", scored: 120, hit: 30 },
      { day: "2026-10-04", scored: 110, hit: 40 },
    ];
    const bars = alarmBars(days);
    expect(bars?.map((bar) => bar.day)).toEqual(["2026-10-01", "2026-10-03", "2026-10-04"]);
    expect(bars?.[0].pct).toBe(25);
    expect(bars?.[0].height).toBe(50);
    expect(alarmBars(days.slice(0, 2))).toBeNull();
  });

  it("counts a district from station groups and treats 멀쩡함 as not broken", () => {
    const rows = districtRows(
      [bike({ bike: "A", station: "1", level: "빨강", p_next: 50 }), bike({ bike: "B", station: "2", p_next: 10 })],
      (item) => (item.station === "1" ? "마포구" : "중구"),
      { 마포구: 3 },
    );
    expect(rows[0]).toMatchObject({ gu: "마포구", bikes: 1, red: 1, inspections: 3 });
    expect(rows[0].expected).toBeCloseTo(0.5);
    const checked = indexChecked([
      { bike: "A", verdict: "타이어", n: 1 },
      { bike: "A", verdict: "멀쩡함", n: 2 },
    ]);
    expect(checked.A).toMatchObject({ total: 3, broken: 1 });
  });
});
