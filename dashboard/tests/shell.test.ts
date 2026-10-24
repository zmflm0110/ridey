import { describe, expect, it } from "vitest";
import { shellMode } from "../lib/shell";

describe("shellMode", () => {
  it("uses a sidebar, a collapsible sidebar, or bottom tabs", () => {
    expect(shellMode(390)).toBe("tabs");
    expect(shellMode(767)).toBe("tabs");
    expect(shellMode(768)).toBe("collapsible");
    expect(shellMode(1024)).toBe("collapsible");
    expect(shellMode(1279)).toBe("collapsible");
    expect(shellMode(1280)).toBe("sidebar");
    expect(shellMode(1440)).toBe("sidebar");
  });
});
