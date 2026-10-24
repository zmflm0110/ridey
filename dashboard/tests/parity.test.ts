import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { groupByStation, listExpect, normalizeBike, stationValue, type Bike, type Checked } from "../lib/priority";
import { meters, pathLength, planRoute, planValue, shareAfter, simulate, withinShift, type LatLon } from "../lib/route";

const routeCases = JSON.parse(readFileSync(new URL("./fixtures/route_value_cases.json", import.meta.url), "utf8"));
const priorityCases = JSON.parse(readFileSync(new URL("./fixtures/priority_cases.json", import.meta.url), "utf8"));
const parity = JSON.parse(readFileSync(new URL("./fixtures/parity.json", import.meta.url), "utf8"));

type Identified = LatLon & { id: string | number };
type Valued = Identified & { n?: number; v: number };

describe("route parity with web/route.js", () => {
  it("matches meters, order, and path length within 1e-6m", () => {
    for (const item of routeCases.meters) {
      expect(Math.abs(meters(item.a, item.b) - item.meters)).toBeLessThan(1e-6);
    }
    for (const item of routeCases.planRoute) {
      const got = planRoute(item.start, item.stops as Identified[]);
      expect(got.map((stop) => stop.id)).toEqual(item.ids);
      expect(Math.abs(pathLength(item.start, got) - item.meters)).toBeLessThan(1e-6);
    }
    for (const item of routeCases.shareAfter) {
      expect(shareAfter(item.h, item.minute)).toBeCloseTo(item.share, 12);
    }
  });

  it("matches planValue order and does not lose to riding the ranking", () => {
    for (const item of routeCases.planValue) {
      const stations = item.stations as Valued[];
      const valueAt = (stop: Valued) => stop.v;
      const got = planValue(item.start, stations, valueAt, item.minutes, item.t0);
      expect(got.map((stop) => stop.id)).toEqual(item.ids);
      const sim = simulate(item.start, got, valueAt, item.t0);
      expect(Math.abs(sim.used - item.used)).toBeLessThan(1e-6);
      expect(Math.abs(sim.value - item.value)).toBeLessThan(1e-9);
      expect(sim.used).toBeLessThanOrEqual(item.minutes + 1e-9);
      if (item.rankIds) {
        const order: Valued[] = item.rankIds.map((id: string) => {
          const stop = stations.find((candidate) => candidate.id === id);
          if (!stop) throw new Error(String(id));
          return stop;
        });
        const ranked = withinShift(item.start, order, item.minutes);
        expect(ranked.map((stop) => stop.id)).toEqual(item.rankIds);
        expect(sim.value + 1e-9).toBeGreaterThanOrEqual(item.rankValue);
        if (item.minutes === 40) expect(sim.value).toBeGreaterThan(item.rankValue);
      }
    }
  });
});

describe("priority parity with web/app.js", () => {
  it("keeps station order, station value, and list expectation", () => {
    for (const item of priorityCases) {
      const bikes = item.bikes as Bike[];
      const checked = item.checked as Record<string, Checked>;
      const groups = groupByStation(bikes, checked);
      expect(groups.map(([id, rows]) => ({ id, bikes: rows.map((bike) => bike.bike) }))).toEqual(item.order);
      const values = groups.map(([id, arr]) =>
        stationValue({ id, arr, n: arr.length, lat: 37.5, lon: 127 }, item.minute, item.routeValue, item.busy),
      );
      values.forEach((value, index) => expect(Math.abs(value - item.values[index])).toBeLessThan(1e-9));
      expect(listExpect(bikes, -1.2816)).toEqual(item.expect);
    }
  });

  it("normalizes bike ids the same way as the web lookup fixture", () => {
    for (const [raw, expected] of parity.lookup as [string, string | null][]) {
      expect(normalizeBike(raw)).toBe(expected);
    }
  });
});
