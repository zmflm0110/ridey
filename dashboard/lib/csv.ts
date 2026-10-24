function cell(value: unknown): string {
  return `"${String(value ?? "").replace(/"/g, '""')}"`;
}

export function csvTable(rows: unknown[][]): string {
  return `\ufeff${rows.map((row) => row.map(cell).join(",")).join("\r\n")}\r\n`;
}

export function routeCsv(
  rows: { order: number; arrival: string; gu: string; id: string; name: string; bikes: number; people: string }[],
): string {
  return csvTable([
    ["순서", "도착", "구", "대여소번호", "대여소", "의심 대수", "막을 헛걸음"],
    ...rows.map((row) => [row.order, row.arrival, row.gu, row.id, row.name, row.bikes, row.people]),
  ]);
}
