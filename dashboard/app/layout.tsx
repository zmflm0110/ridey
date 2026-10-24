import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RIDEY Operations",
  description: "따릉이 고장 의심 자전거를 직원이 보고 점검하는 화면",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
