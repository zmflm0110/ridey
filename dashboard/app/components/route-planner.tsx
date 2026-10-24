"use client";

import { useMemo, useState } from "react";
import { RouteMap } from "@/app/components/route-map";
import busyData from "@/data/busy.json";
import routeValueData from "@/data/route_value.json";
import { routeCsv } from "@/lib/csv";
import type { Bike, RouteValueTable } from "@/lib/priority";
import { seoulParts } from "@/lib/seoul";
import { hhmm, people, planShift, SERVICE_CENTER_ID } from "@/lib/shift";
import { stationById, stationList } from "@/lib/stations";

const routeValue = routeValueData as RouteValueTable;
const busy = busyData as Record<string, number[]>;
const presets = [60, 90, 180];

function download(filename: string, body: string) {
  const link = document.createElement("a");
  link.href = URL.createObjectURL(new Blob([body], { type: "text/csv;charset=utf-8" }));
  link.download = filename;
  document.body.append(link);
  link.click();
  setTimeout(() => {
    URL.revokeObjectURL(link.href);
    link.remove();
  }, 1000);
}

export function RoutePlanner({
  bikes,
  districts,
  source,
  day,
}: {
  bikes: Bike[];
  districts: string[];
  source: "live" | "morning";
  day: string | null;
}) {
  const [minutes, setMinutes] = useState(90);
  const [gu, setGu] = useState(districts.length === 1 ? districts[0] : "");
  const [mode, setMode] = useState<"value" | "here" | "center" | "station">("value");
  const [query, setQuery] = useState("");
  const [stationId, setStationId] = useState("");
  const [here, setHere] = useState<{ lat: number; lon: number } | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const clock = seoulParts();
  const t0 = source === "live" || day === clock.date ? clock.minutes : 9 * 60;
  const gus = [...new Set(bikes.map((bike) => stationById.get(bike.station)?.gu || "기타"))].sort((a, b) => a.localeCompare(b, "ko"));
  const options = districts.length ? districts : gus;
  const matches = useMemo(() => {
    const text = query.trim().replace(/\s+/g, "");
    if (!text) return [];
    return stationList.filter((station) => station.name.replace(/\s+/g, "").includes(text)).slice(0, 8);
  }, [query]);
  const center = stationById.get(SERVICE_CENTER_ID) ?? null;
  const chosen = stationById.get(stationId) ?? null;
  const external = useMemo(() => {
    if (mode === "here" && here) return { lat: here.lat, lon: here.lon, name: "내 위치" };
    if (mode === "center") return center;
    if (mode === "station") return chosen;
    return null;
  }, [mode, here, center, chosen]);
  const plan = useMemo(
    () => planShift({
      bikes,
      stations: stationById,
      routeValue,
      busy,
      minutes,
      t0,
      start: external,
      gu: gu || undefined,
    }),
    [bikes, minutes, t0, external, gu],
  );

  async function useHere() {
    setMode("here");
    if (!navigator.geolocation) {
      setMessage("이 브라우저에서는 위치를 쓸 수 없어요.");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setHere({ lat: position.coords.latitude, lon: position.coords.longitude });
        setMessage(null);
      },
      () => setMessage("위치를 가져오지 못했어요. 대여소나 센터를 출발점으로 고르세요."),
      { enableHighAccuracy: true, timeout: 8000 },
    );
  }

  const extra = plan && plan.value > plan.rankValue + 0.05 ? `순위대로 돌 때보다 ${(plan.value - plan.rankValue).toFixed(1)}명 더 막아요.` : "순위대로 도는 것과 같아요.";

  return (
    <div className="stack">
      <div className="filters">
        <label>
          남은 시간
          <span className="choice">
            {presets.map((preset) => (
              <button key={preset} type="button" aria-pressed={minutes === preset} onClick={() => setMinutes(preset)}>
                {preset}분
              </button>
            ))}
            <input
              aria-label="직접 입력(분)"
              type="number"
              min={15}
              max={480}
              value={minutes}
              onChange={(event) => setMinutes(Math.min(480, Math.max(15, Number(event.target.value) || 15)))}
            />
          </span>
        </label>
        <label>
          자치구
          <select value={gu} onChange={(event) => setGu(event.target.value)}>
            <option value="">전체</option>
            {options.map((item) => <option key={item}>{item}</option>)}
          </select>
        </label>
        <label>
          출발
          <select value={mode} onChange={(event) => setMode(event.target.value as typeof mode)}>
            <option value="value">값이 가장 큰 대여소</option>
            <option value="here">현재 위치</option>
            <option value="center">상암센터</option>
            <option value="station">대여소</option>
          </select>
        </label>
        {mode === "here" ? <button type="button" onClick={useHere}>위치 받기</button> : null}
        {mode === "station" ? (
          <label>
            대여소 찾기
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="이름" />
          </label>
        ) : null}
      </div>
      {mode === "station" && matches.length ? (
        <div className="choice">
          {matches.map((station) => (
            <button key={station.id} type="button" aria-pressed={station.id === stationId} onClick={() => { setStationId(station.id); setQuery(station.name); }}>
              {station.name}
            </button>
          ))}
        </div>
      ) : null}
      {message ? <p role="status">{message}</p> : null}
      {plan.stops.length ? (
        <>
          <p>{plan.stops.length}곳 · 약 {Math.round(plan.used)}분 · 막을 헛걸음 {people(plan.value)}. {extra}</p>
          <div className="filters print-hide">
            <button type="button" onClick={() => window.print()}>인쇄</button>
            <button
              type="button"
              onClick={() => download(`route_${day || clock.date}.csv`, routeCsv(plan.stops.map((stop, index) => ({
                order: index + 1,
                arrival: hhmm(stop.arrival),
                gu: stop.gu,
                id: stop.id,
                name: stop.name,
                bikes: stop.n,
                people: people(stop.value),
              }))))}
            >
              CSV
            </button>
          </div>
          <RouteMap start={plan.origin} stops={plan.stops} />
          <ol className="route-list">
            {plan.stops.map((stop, index) => (
              <li key={stop.id}>
                <b>{index + 1}. {stop.name}</b>
                <span>{hhmm(stop.arrival)} 도착 · {stop.gu} · 의심 {stop.n}대 · {people(stop.value)}</span>
              </li>
            ))}
          </ol>
        </>
      ) : <p>이 조건으로 돌 대여소가 없어요.</p>}
    </div>
  );
}
