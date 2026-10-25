"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { LogoutButton } from "@/app/components/logout-button";
import { shellNav } from "@/lib/shell";

export function OperationsShell({ children, demo = false }: { children: React.ReactNode; demo?: boolean }) {
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
        {demo ? <p className="demo-badge">둘러보기 · 읽기 전용</p> : null}
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
        {demo ? null : <LogoutButton />}
      </aside>
      <main className="content">
        {demo ? (
          <p className="demo-bar" role="note">
            둘러보기예요. 공개된 실시간 자료만 보이고, 현장 판정은 저장하지 않아요.
          </p>
        ) : null}
        {children}
      </main>
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
