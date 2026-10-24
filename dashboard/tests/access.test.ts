import { describe, expect, it } from "vitest";
import { parseStaffProfile, staffAccess, staffRedirect, type StaffProfile } from "../lib/auth/access";

const staff: StaffProfile = {
  email: "staff@example.com",
  role: "staff",
  districts: ["마포구"],
  active: true,
};

describe("staff access", () => {
  it("sends anonymous, non-staff, inactive, and staff to different places", () => {
    expect(staffAccess(null, null).status).toBe("anonymous");
    expect(staffAccess({ id: "user" }, null).status).toBe("forbidden");
    expect(staffAccess({ id: "user" }, { ...staff, active: false }).status).toBe("forbidden");
    expect(staffAccess({ id: "user" }, staff)).toEqual({ status: "staff", profile: staff });

    expect(staffRedirect(staffAccess(null, null), "/overview")).toBe("/login");
    expect(staffRedirect(staffAccess({ id: "user" }, null), "/overview")).toBe("/forbidden");
    expect(staffRedirect(staffAccess({ id: "user" }, { ...staff, active: false }), "/field")).toBe(
      "/forbidden",
    );
    expect(staffRedirect(staffAccess({ id: "user" }, staff), "/priority")).toBeNull();
    expect(staffRedirect(staffAccess({ id: "user" }, staff), "/login")).toBe("/overview");
    expect(staffRedirect(staffAccess(null, null), "/forbidden")).toBe("/login");
    expect(staffRedirect(staffAccess({ id: "user" }, staff), "/forbidden")).toBe("/overview");
  });

  it("ignores a staff_me payload that is not an active profile", () => {
    expect(parseStaffProfile(null)).toBeNull();
    expect(parseStaffProfile({ email: "a@b.c", role: "owner", active: true })).toBeNull();
    expect(parseStaffProfile({ email: "a@b.c", role: "developer", districts: ["강남구"], active: true }))
      .toMatchObject({ role: "developer", districts: ["강남구"], active: true });
  });
});
