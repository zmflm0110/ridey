"use client";

import { useMemo, useState } from "react";
import { StationMap, type MapGroup } from "@/app/components/station-map";
import { groupByStation, levelLabel, type Bike } from "@/lib/priority";
import { checkedCounts, type CheckedDetail } from "@/lib/snapshot";
import type { Station } from "@/lib/stations";

export function PriorityBoard({
  bikes,
  districts,
  checked,
  stations,
}: {
  bikes: Bike[];
  districts: string[];
  checked: Record<string, CheckedDetail>;
  stations: Station[];
}) {
  const [gu, setGu] = useState(districts.length === 1 ? districts[0] : districts.length ? "__mine__" : "");
  const [level, setLevel] = useState("");
  const [picked, setPicked] = useState<string[]>([]);
  const [open, setOpen] = useState<string | null>(null);
  const counts = useMemo(() => checkedCounts(checked), [checked]);
  const byId = useMemo(() => new Map(stations.map((station) => [station.id, station])), [stations]);
  const visible = useMemo(
    () =>
      bikes.filter((bike) => {
        const district = byId.get(bike.station)?.gu || "기타";
        if (gu === "__mine__" && !districts.includes(district)) return false;
        if (gu && gu !== "__mine__" && district !== gu) return false;
        if (level && bike.level !== level) return false;
        return true;
      }),
    [bikes, byId, gu, level, districts],
  );
  const groups = useMemo(() => groupByStation(visible, counts), [visible, counts]);
  const gus = [...new Set(bikes.map((bike) => byId.get(bike.station)?.gu || "기타"))].sort((a, b) => a.localeCompare(b, "ko"));
  const mapGroups = useMemo<MapGroup[]>(
    () =>
      groups.flatMap(([id, rows]) => {
        const station = byId.get(id);
        if (!station) return [];
        return [{
          id,
          name: station.name,
          lat: station.lat,
          lon: station.lon,
          bikes: rows,
          red: rows.some((bike) => bike.level === "빨강"),
        }];
      }),
    [groups, byId],
  );
  const openBike = visible.find((bike) => bike.bike === open) ?? null;
  const compared = picked.flatMap((id) => {
    const bike = visible.find((item) => item.bike === id);
    return bike ? [bike] : [];
  });

  function toggle(id: string) {
    setPicked((current) => {
      if (current.includes(id)) return current.filter((item) => item !== id);
      if (current.length >= 4) return current;
      return [...current, id];
    });
  }

  return (
    <div className="stack">
      <div className="filters">
        <label>
          자치구
          <select value={gu} onChange={(event) => setGu(event.target.value)}>
            {districts.length ? <option value="__mine__">담당 구</option> : <option value="">전체</option>}
            {(districts.length ? districts : gus).map((item) => (
              <option key={item} value={item}>{item}</option>
            ))}
            {districts.length ? <option value="">전체</option> : null}
          </select>
        </label>
        <label>
          단계
          <select value={level} onChange={(event) => setLevel(event.target.value)}>
            <option value="">전체</option>
            <option value="빨강">강한 경보 · 3명 이상</option>
            <option value="노랑">경보 · 2명</option>
          </select>
        </label>
        <p className="hint">{visible.length}대 · 비교는 4대까지</p>
      </div>
      <StationMap groups={mapGroups} />
      {compared.length > 1 ? (
        <div className="compare">
          {compared.map((bike) => (
            <article key={bike.bike}>
              <b>{bike.bike}</b>
              <span>{bike.station_name}</span>
              <span>{bike.p_next != null ? `${bike.p_next}%` : `${bike.chain}명`}</span>
              <span>{levelLabel(bike.level)}</span>
            </article>
          ))}
        </div>
      ) : null}
      <div className="split">
        <div className="table-wrap">
          <table>
            <caption>대여소</caption>
            <thead>
              <tr><th>대여소</th><th>구</th><th>대수</th><th>사람 확인</th></tr>
            </thead>
            <tbody>
              {groups.map(([id, rows]) => {
                const station = byId.get(id);
                const confirmed = rows.filter((bike) => (counts[bike.bike]?.broken ?? 0) > 0).length;
                return (
                  <tr key={id}>
                    <td>{station?.name || rows[0]?.station_name || id}</td>
                    <td>{station?.gu || "기타"}</td>
                    <td>{rows.length}</td>
                    <td>{confirmed ? `${confirmed}대` : ""}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="table-wrap">
          <table>
            <caption>자전거</caption>
            <thead>
              <tr><th>비교</th><th>번호</th><th>대여소</th><th>단계</th><th>확률</th></tr>
            </thead>
            <tbody>
              {visible.map((bike) => (
                <tr key={bike.bike}>
                  <td>
                    <input
                      type="checkbox"
                      aria-label={`${bike.bike} 비교`}
                      checked={picked.includes(bike.bike)}
                      onChange={() => toggle(bike.bike)}
                    />
                  </td>
                  <td>
                    <button type="button" className="text-button" onClick={() => setOpen(bike.bike)}>
                      {bike.bike}
                    </button>
                  </td>
                  <td>{bike.station_name}</td>
                  <td>{levelLabel(bike.level)}</td>
                  <td>{bike.p_next != null ? `${bike.p_next}%` : `${bike.chain}명`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      {openBike ? (
        <aside className="drawer" role="dialog" aria-label={`${openBike.bike} 판단 근거`}>
          <button type="button" className="text-button" onClick={() => setOpen(null)}>닫기</button>
          <h2>{openBike.bike}</h2>
          <p>{openBike.station_name} · {levelLabel(openBike.level)} · {openBike.p_next != null ? `다음 사람도 바로 반납할 확률 ${openBike.p_next}%` : `${openBike.chain}명 연속`}</p>
          <h3>왜 이 확률?</h3>
          <ul>
            {(Array.isArray(openBike.why) ? openBike.why : []).map((reason, index) => (
              <li key={`${reason.t}-${index}`}>{reason.t}{typeof reason.d === "number" ? ` (${reason.d > 0 ? "+" : ""}${reason.d}%p)` : ""}</li>
            ))}
          </ul>
          {(Array.isArray(openBike.why) ? openBike.why : []).length === 0 ? <p>적힌 판단 근거가 없어요.</p> : null}
          <h3>사람 확인</h3>
          {checked[openBike.bike]?.verdicts.length ? (
            <ul>
              {checked[openBike.bike].verdicts.map((item) => (
                <li key={item.verdict}>{item.verdict} {item.n}</li>
              ))}
            </ul>
          ) : <p>아직 확인 기록이 없어요.</p>}
        </aside>
      ) : null}
    </div>
  );
}
