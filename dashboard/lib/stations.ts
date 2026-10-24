import stations from "@/data/stations.json";

export type Station = { id: string; name: string; gu: string; lat: number; lon: number };

export const stationList: Station[] = (stations as Station[]).map((station) => ({
  ...station,
  name: station.name.trim(),
}));

export const stationById: ReadonlyMap<string, Station> = new Map(stationList.map((station) => [station.id, station]));

export function guOf(stationId: string): string {
  return stationById.get(stationId)?.gu || "기타";
}
