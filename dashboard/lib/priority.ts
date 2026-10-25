// web/app.js 의 대여소 순위·대여소 값. 정렬 키와 식을 바꾸지 않는다.

import { shareAfter } from "@/lib/route";

export type Bike = {
  bike: string;
  station: string;
  station_name: string;
  chain: number;
  level: string;
  last_dud?: string;
  minutes_ago?: number | null;
  reported?: boolean | null;
  p_next?: number | null;
  why?: { t?: string; d?: number }[] | null;
  truth_first_rider_dud?: boolean | null;
};

export type Checked = { total: number; broken: number };

export type RouteValueTable = {
  cuts: number[];
  value: Record<string, number[]>;
};

export type ValuedStop = {
  id: string;
  lat?: number;
  lon?: number;
  n?: number;
  arr: Bike[];
};

const emptyChecked: Checked = { total: 0, broken: 0 };

/** 엔진의 단계 값(빨강·노랑)을 화면 말로. 브랜드는 색 이름 대신 경보의 세기로 부른다(docs/brand.md). */
export function levelLabel(level: string): string {
  if (level === "빨강") return "강한 경보";
  if (level === "노랑") return "경보";
  return level;
}

export function normalizeBike(raw: string): string | null {
  const match = String(raw).toUpperCase().match(/SPB-?\s?(\d{3,6})/);
  return match ? `SPB-${match[1].padStart(5, "0")}` : null;
}

export function expectOf(bikes: Bike[]): number | null {
  return bikes.some((bike) => bike.p_next != null)
    ? bikes.reduce((total, bike) => total + (bike.p_next || 0) / 100, 0)
    : null;
}

export function listExpect(bikes: Bike[], q: number | null | undefined): { mu: number; atLeast: number } | null {
  if (q == null || !bikes.length || bikes.some((bike) => bike.p_next == null)) return null;
  const probabilities = bikes.map((bike) => (bike.p_next ?? 0) / 100);
  const mu = probabilities.reduce((sum, probability) => sum + probability, 0);
  const sd = Math.sqrt(probabilities.reduce((sum, probability) => sum + probability * (1 - probability), 0));
  return { mu, atLeast: Math.max(0, Math.floor(mu + q * sd)) };
}

function sumBroken(bikes: Bike[], checked: Record<string, Checked>): number {
  return bikes.filter((bike) => (checked[bike.bike] || emptyChecked).broken > 0).length;
}

function sumChain(bikes: Bike[]): number {
  return bikes.reduce((total, bike) => total + bike.chain, 0);
}

export function groupByStation(
  bikes: Bike[],
  checked: Record<string, Checked> = {},
): [string, Bike[]][] {
  const groups: Record<string, Bike[]> = {};
  bikes.forEach((bike) => (groups[bike.station] = groups[bike.station] || []).push(bike));
  return Object.entries(groups).sort(
    (a, b) =>
      sumBroken(b[1], checked) - sumBroken(a[1], checked) ||
      (expectOf(b[1]) ?? 0) - (expectOf(a[1]) ?? 0) ||
      sumChain(b[1]) - sumChain(a[1]) ||
      b[1].length - a[1].length,
  );
}

export function stationValue(
  stop: ValuedStop,
  minute: number,
  routeValue: RouteValueTable | null,
  busy: Record<string, number[]> | null,
): number {
  if (!routeValue) return stop.arr.length * Math.max(0, (1440 - minute) / 1440);
  const row = busy?.[stop.id];
  const average = row ? row[0] : 0;
  const hours = row ? row.slice(1).map((value) => value + 0.5) : Array(24).fill(1);
  const level = average < routeValue.cuts[0] ? 0 : average < routeValue.cuts[1] ? 1 : 2;
  return (
    stop.arr.reduce((total, bike) => {
      const chain = String(Math.min(Math.max(bike.chain, 2), 4));
      return total + routeValue.value[chain][level];
    }, 0) * shareAfter(hours, minute)
  );
}
