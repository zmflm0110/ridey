import { groupByStation, stationValue, type Bike, type RouteValueTable } from "@/lib/priority";
import { planRoute, planValue, simulate, withinShift, type LatLon } from "@/lib/route";
import type { Station } from "@/lib/stations";

export const SERVICE_CENTER_ID = "00420";

export type ShiftStop = Station & { n: number; arr: Bike[] };

export type ShiftPlan = {
  stops: (ShiftStop & { arrival: number; value: number })[];
  used: number;
  value: number;
  rankValue: number;
  origin: (LatLon & { name: string }) | null;
};

export function hhmm(minute: number): string {
  return `${String(Math.floor(minute / 60) % 24).padStart(2, "0")}:${String(Math.floor(minute % 60)).padStart(2, "0")}`;
}

export function people(value: number): string {
  return value < 0.05 ? "0.1명 미만" : `${value.toFixed(1)}명`;
}

export function planShift(input: {
  bikes: Bike[];
  stations: ReadonlyMap<string, Station>;
  routeValue: RouteValueTable | null;
  busy: Record<string, number[]> | null;
  minutes: number;
  t0: number;
  start?: (LatLon & { name?: string }) | null;
  gu?: string;
}): ShiftPlan {
  const bikes = input.gu ? input.bikes.filter((bike) => (input.stations.get(bike.station)?.gu || "기타") === input.gu) : input.bikes;
  const asStop = ([id, arr]: [string, Bike[]]): ShiftStop | null => {
    const station = input.stations.get(id);
    if (!station) return null;
    return { ...station, n: arr.length, arr };
  };
  const located = groupByStation(bikes).flatMap((group) => {
    const stop = asStop(group);
    return stop ? [stop] : [];
  });
  const valueAt = (stop: ShiftStop, minute: number) => stationValue(stop, minute, input.routeValue, input.busy);
  const pool = located.slice().sort((a, b) => valueAt(b, input.t0) - valueAt(a, input.t0)).slice(0, 40);
  const ranked = located.slice(0, 10);
  const start = input.start ?? pool[0];
  if (!start || !pool.length) {
    return { stops: [], used: 0, value: 0, rankValue: 0, origin: null };
  }
  const stops = planValue(start, pool, valueAt, input.minutes, input.t0);
  const sim = simulate(start, stops, valueAt, input.t0);
  const rankStops = withinShift(start, planRoute(start, ranked), input.minutes);
  const rankValue = simulate(start, rankStops, valueAt, input.t0).value;
  const named = input.start && "name" in input.start ? input.start.name : pool[0]?.name;
  return {
    stops: stops.map((stop, index) => ({ ...stop, arrival: sim.arr[index], value: valueAt(stop, sim.arr[index]) })),
    used: sim.used,
    value: sim.value,
    rankValue,
    origin: { lat: start.lat, lon: start.lon, name: named || "출발" },
  };
}
