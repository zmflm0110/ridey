import { describe, expect, it } from "vitest";
import { makeDraft, photoName, readQueue, surveyPayload, writeQueue } from "../lib/field";

describe("field queue", () => {
  it("keeps the original time and drops a point outside Seoul", () => {
    const at = "2026-10-25T01:02:03.000Z";
    const draft = makeDraft({
      at,
      station: "00420",
      rawBike: "spb 123",
      status: "타이어",
      note: " 앞바퀴 ",
      lat: 10,
      lon: 10,
      photo: null,
    });
    expect(draft).toMatchObject({ at, bike: "SPB-00123", note: "앞바퀴", lat: null, lon: null, station: "00420" });
    const payload = surveyPayload(draft!, "ab".repeat(8) + ".jpg");
    expect(payload.at).toBe(at);
    expect(payload.photo).toMatch(/^[0-9a-f]{16}\.jpg$/);
    expect(makeDraft({ ...{ at, station: null, rawBike: "hello", status: "멀쩡함", note: "", lat: null, lon: null, photo: null } })).toBeNull();
  });

  it("names a photo with 16 hex characters and round-trips the queue", () => {
    expect(photoName(new Uint8Array([0, 1, 10, 15, 16, 255, 2, 3]))).toBe("00010a0f10ff0203.jpg");
    const memory = new Map<string, string>();
    const storage = {
      getItem: (key: string) => memory.get(key) ?? null,
      setItem: (key: string, value: string) => void memory.set(key, value),
    };
    const draft = makeDraft({
      at: "2026-10-25T00:00:00.000Z",
      station: null,
      rawBike: "SPB-00001",
      status: "멀쩡함",
      note: "",
      lat: 37.5,
      lon: 127,
      photo: null,
    })!;
    expect(writeQueue(storage, [draft])).toBe(true);
    expect(readQueue(storage)[0].at).toBe(draft.at);
  });
});
