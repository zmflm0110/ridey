"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  dataUrlToBlob,
  FIELD_STATUSES,
  makeDraft,
  photoName,
  readQueue,
  shrinkPhoto,
  surveyPayload,
  writeQueue,
  type FieldDraft,
  type FieldStatus,
} from "@/lib/field";
import type { Bike } from "@/lib/priority";
import { createClient } from "@/lib/supabase/client";
import { stationById, stationList } from "@/lib/stations";

async function sendDraft(draft: FieldDraft): Promise<boolean> {
  const supabase = createClient();
  if (!supabase) return false;
  let photo: string | null = null;
  if (draft.photo) {
    const name = photoName();
    const uploaded = await supabase.storage.from("survey-photos").upload(name, dataUrlToBlob(draft.photo), {
      contentType: "image/jpeg",
      upsert: false,
    });
    if (uploaded.error) return false;
    photo = name;
  }
  const inserted = await supabase.from("survey").insert(surveyPayload(draft, photo));
  return !inserted.error;
}

export function FieldDesk({ bikes }: { bikes: Bike[] }) {
  const [query, setQuery] = useState("");
  const [stationId, setStationId] = useState("");
  const [bike, setBike] = useState("");
  const [note, setNote] = useState("");
  const [photo, setPhoto] = useState<string | null>(null);
  const [point, setPoint] = useState<{ lat: number; lon: number } | null>(null);
  const [pending, setPending] = useState(0);
  const [message, setMessage] = useState<string | null>(null);

  const chain = useRef(Promise.resolve());

  function flush() {
    const run = chain.current.then(async () => {
      const queue = readQueue(localStorage);
      const left: FieldDraft[] = [];
      for (const draft of queue) {
        try {
          if (!(await sendDraft(draft))) left.push(draft);
        } catch {
          left.push(draft);
        }
      }
      writeQueue(localStorage, left);
      setPending(left.length);
      return left.length;
    });
    chain.current = run.then(() => undefined, () => undefined);
    return run;
  }

  useEffect(() => {
    void flush();
    const onOnline = () => void flush();
    window.addEventListener("online", onOnline);
    return () => window.removeEventListener("online", onOnline);
  }, []);

  const matches = useMemo(() => {
    const text = query.trim().replace(/\s+/g, "");
    const source = text ? stationList.filter((station) => station.name.replace(/\s+/g, "").includes(text)) : stationList;
    return source.slice(0, 8);
  }, [query]);
  const station = stationById.get(stationId) ?? null;
  const suspects = bikes.filter((item) => item.station === stationId);

  async function save(status: FieldStatus) {
    const draft = makeDraft({
      at: new Date().toISOString(),
      station: stationId || null,
      rawBike: bike,
      status,
      note,
      lat: point?.lat ?? null,
      lon: point?.lon ?? null,
      photo,
    });
    if (!draft) {
      setMessage("자전거 번호(SPB-00000)를 먼저 넣어 주세요.");
      return;
    }
    const stored = writeQueue(localStorage, [...readQueue(localStorage), draft]);
    if (!stored && draft.photo) {
      writeQueue(localStorage, [...readQueue(localStorage), { ...draft, photo: null }]);
      setMessage("저장 공간이 모자라 사진은 빼고 보관했어요.");
    }
    const left = await flush();
    setBike("");
    setNote("");
    setPhoto(null);
    setMessage(`${draft.bike} → ${status}${left ? ` · 못 보낸 ${left}건은 원래 시각 그대로 보관 중` : ""}`);
  }

  return (
    <div className="stack">
      <label>
        대여소
        <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="이름" />
      </label>
      <div className="choice">
        {matches.map((item) => (
          <button key={item.id} type="button" aria-pressed={item.id === stationId} onClick={() => setStationId(item.id)}>
            {item.name}
          </button>
        ))}
      </div>
      {station ? <p>{station.name} · {station.gu} · 의심 {suspects.length}대</p> : <p>대여소를 고르면 그곳의 의심 자전거가 나와요.</p>}
      <div className="choice">
        {suspects.map((item) => (
          <button key={item.bike} type="button" className={item.level === "빨강" ? "bad" : ""} onClick={() => setBike(item.bike)}>
            {item.bike}
          </button>
        ))}
      </div>
      <label>
        자전거 번호
        <input value={bike} onChange={(event) => setBike(event.target.value)} placeholder="SPB-00000" autoCapitalize="characters" />
      </label>
      <label>
        메모
        <input value={note} maxLength={200} onChange={(event) => setNote(event.target.value)} />
      </label>
      <label className="file">
        사진 붙이기 (선택, 긴 변 1280px)
        <input
          type="file"
          accept="image/*"
          capture="environment"
          onChange={async (event) => {
            const file = event.target.files?.[0];
            event.target.value = "";
            if (!file) return;
            try {
              setPhoto(await shrinkPhoto(file));
            } catch {
              setPhoto(null);
              setMessage("사진을 읽지 못했어요.");
            }
          }}
        />
      </label>
      {photo ? <p className="hint">사진이 붙었어요.</p> : null}
      <button
        type="button"
        onClick={() => {
          if (!navigator.geolocation) return;
          navigator.geolocation.getCurrentPosition(
            (position) => setPoint({ lat: position.coords.latitude, lon: position.coords.longitude }),
            () => setMessage("위치를 가져오지 못했어요. 기록은 위치 없이 남길 수 있어요."),
            { enableHighAccuracy: true, timeout: 8000 },
          );
        }}
      >
        {point ? "현재 위치를 붙여 두었어요" : "현재 위치 붙이기"}
      </button>
      <div className="choice verdicts">
        {FIELD_STATUSES.map((status) => (
          <button key={status} type="button" className={status === "멀쩡함" ? "" : "bad"} onClick={() => void save(status)}>
            {status}
          </button>
        ))}
      </div>
      <p className="hint">{pending ? `서버에 못 보낸 ${pending}건은 이 브라우저에 있어요.` : "대기 중인 기록이 없어요."}</p>
      {message ? <p role="status">{message}</p> : null}
    </div>
  );
}
