import { describe, expect, it } from "vitest";
import { levelLabel } from "../lib/priority";
import { seoulStamp } from "../lib/seoul";

describe("screen labels", () => {
  it("shows a Seoul clock instead of the raw timestamp", () => {
    expect(seoulStamp("2026-10-25T15:40:00.198295")).toBe("10월 25일 15:40");
    expect(seoulStamp("2026-10-25T06:40:00+00:00")).toBe("10월 25일 15:40");
    expect(seoulStamp("2026-10-24T23:05:00Z")).toBe("10월 25일 08:05");
    expect(seoulStamp(null)).toBe("");
    expect(seoulStamp("어제")).toBe("어제");
  });

  it("names alert levels by strength, not by color", () => {
    expect(levelLabel("빨강")).toBe("강한 경보");
    expect(levelLabel("노랑")).toBe("경보");
    expect(levelLabel("")).toBe("");
  });
});
