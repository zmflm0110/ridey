"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { shellNav } from "@/lib/shell";

export function OperationsShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <div className="shell" data-open={open ? "true" : "false"}>
      <button
        type="button"
        className="menu-button"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        메뉴
      </button>
      <button
        type="button"
        className="backdrop"
        aria-label="메뉴 닫기"
        onClick={() => setOpen(false)}
      />
      <aside className="sidebar">
        <div className="wordmark">
          RIDEY<i />
        </div>
        <nav aria-label="운영">
          {shellNav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="nav-link"
              aria-current={pathname === item.href ? "page" : undefined}
              onClick={() => setOpen(false)}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      </aside>
      <main className="content">{children}</main>
      <nav className="tabbar" aria-label="운영 탭">
        {shellNav.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className="tab"
            aria-current={pathname === item.href ? "page" : undefined}
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </div>
  );
}
