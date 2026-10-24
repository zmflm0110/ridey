// web/route.js 와 같은 계산. 순서를 바꾸지 않는다.
// planRoute: 가까운 곳부터 + 2-opt. planValue: 근무 시간 안에 막을 헛걸음이 가장 많은 곳과 순서.

export type LatLon = { lat: number; lon: number };

export const SHIFT = { kmh: 18, detour: 1.3, stopMin: 6, bikeMin: 4 };

export function meters(a: LatLon, b: LatLon): number {
  const R = 6371000;
  const toR = Math.PI / 180;
  const dLat = (b.lat - a.lat) * toR;
  const dLon = (b.lon - a.lon) * toR;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * toR) * Math.cos(b.lat * toR) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

export function pathLength(start: LatLon, stops: LatLon[]): number {
  let total = 0;
  let cur = start;
  for (const stop of stops) {
    total += meters(cur, stop);
    cur = stop;
  }
  return total;
}

export function planRoute<T extends LatLon>(start: LatLon, stops: T[]): T[] {
  const left = stops.slice();
  const order: T[] = [];
  let cur: LatLon = start;
  while (left.length) {
    let k = 0;
    for (let i = 1; i < left.length; i++) if (meters(cur, left[i]) < meters(cur, left[k])) k = i;
    const next = left.splice(k, 1)[0];
    cur = next;
    order.push(next);
  }
  const pts: LatLon[] = [start, ...order];
  for (let improved = true, guard = 0; improved && guard < 50; guard++) {
    improved = false;
    for (let i = 1; i < pts.length - 1; i++) {
      for (let j = i + 1; j < pts.length; j++) {
        const a = pts[i - 1];
        const b = pts[i];
        const c = pts[j];
        const d = pts[j + 1];
        const before = meters(a, b) + (d ? meters(c, d) : 0);
        const after = meters(a, c) + (d ? meters(b, d) : 0);
        if (after < before - 1e-6) {
          pts.splice(i, j - i + 1, ...pts.slice(i, j + 1).reverse());
          improved = true;
        }
      }
    }
  }
  return pts.slice(1) as T[];
}

export const travelMin = (a: LatLon, b: LatLon) =>
  (meters(a, b) * SHIFT.detour) / 1000 / SHIFT.kmh * 60;

export type TimedStop = LatLon & { n?: number };

export function simulate<T extends TimedStop>(
  start: LatLon,
  route: T[],
  valueAt: (stop: T, minute: number) => number,
  t0 = 0,
): { used: number; value: number; arr: number[] } {
  let t = 0;
  let value = 0;
  let cur: LatLon = start;
  const arr: number[] = [];
  for (const stop of route) {
    t += travelMin(cur, stop);
    arr.push(t0 + t);
    value += valueAt(stop, t0 + t);
    t += SHIFT.stopMin + SHIFT.bikeMin * (stop.n || 1);
    cur = stop;
  }
  return { used: t, value, arr };
}

function twoOptValue<T extends TimedStop>(
  start: LatLon,
  route: T[],
  valueAt: (stop: T, minute: number) => number,
  minutes: number,
  t0: number,
): T[] {
  let best = simulate(start, route, valueAt, t0);
  for (let improved = true, guard = 0; improved && guard < 30; guard++) {
    improved = false;
    for (let i = 0; i < route.length - 1; i++) {
      for (let j = i + 1; j < route.length; j++) {
        const cand = [...route.slice(0, i), ...route.slice(i, j + 1).reverse(), ...route.slice(j + 1)];
        const result = simulate(start, cand, valueAt, t0);
        if (
          result.used <= minutes &&
          (result.value > best.value + 1e-9 ||
            (Math.abs(result.value - best.value) <= 1e-9 && result.used < best.used - 1e-6))
        ) {
          route = cand;
          best = result;
          improved = true;
        }
      }
    }
  }
  return route;
}

function greedyFill<T extends TimedStop>(
  start: LatLon,
  seed: T[],
  pool: T[],
  valueAt: (stop: T, minute: number) => number,
  minutes: number,
  t0: number,
  mode: "ratio" | "value",
): T[] {
  let route = seed.slice();
  const left = pool.filter((stop) => !route.includes(stop));
  while (left.length) {
    const base = simulate(start, route, valueAt, t0);
    let best: { score: number; cand: T[]; stop: T } | null = null;
    for (const stop of left) {
      for (let pos = 0; pos <= route.length; pos++) {
        const cand = [...route.slice(0, pos), stop, ...route.slice(pos)];
        const result = simulate(start, cand, valueAt, t0);
        if (result.used > minutes || result.value <= base.value + 1e-9) continue;
        const score =
          mode === "ratio"
            ? (result.value - base.value) / Math.max(result.used - base.used, 1e-6)
            : result.value - base.value;
        if (!best || score > best.score) best = { score, cand, stop };
      }
    }
    if (!best) break;
    route = twoOptValue(start, best.cand, valueAt, minutes, t0);
    left.splice(left.indexOf(best.stop), 1);
  }
  return route;
}

export function planValue<T extends TimedStop>(
  start: LatLon,
  stations: T[],
  valueAt: (stop: T, minute: number) => number,
  minutes: number,
  t0 = 0,
): T[] {
  const byValue = stations.slice().sort((a, b) => valueAt(b, t0) - valueAt(a, t0));
  const seeded = twoOptValue(start, withinShift(start, byValue, minutes), valueAt, minutes, t0);
  const candidates = [
    greedyFill(start, [], stations, valueAt, minutes, t0, "ratio"),
    greedyFill(start, [], stations, valueAt, minutes, t0, "value"),
    greedyFill(start, seeded, stations, valueAt, minutes, t0, "ratio"),
  ];
  return candidates.reduce((best, route) =>
    simulate(start, route, valueAt, t0).value > simulate(start, best, valueAt, t0).value + 1e-9 ? route : best,
  );
}

export function withinShift<T extends TimedStop>(start: LatLon, order: T[], minutes: number): T[] {
  const out: T[] = [];
  let t = 0;
  let cur: LatLon = start;
  for (const stop of order) {
    const end = t + travelMin(cur, stop) + SHIFT.stopMin + SHIFT.bikeMin * (stop.n || 1);
    if (end > minutes) break;
    out.push(stop);
    t = end;
    cur = stop;
  }
  return out;
}

export function shareAfter(hours: number[], minute: number): number {
  const hour = Math.floor(minute / 60);
  if (hour >= 24) return 0;
  const total = hours.reduce((sum, value) => sum + value, 0);
  if (!total) return Math.max(0, (1440 - minute) / 1440);
  let rest = hours[hour] * (1 - (minute % 60) / 60);
  for (let i = hour + 1; i < 24; i++) rest += hours[i];
  return rest / total;
}
