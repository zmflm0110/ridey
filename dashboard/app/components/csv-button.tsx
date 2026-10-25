"use client";

export function CsvButton({ filename, csv, label }: { filename: string; csv: string; label: string }) {
  return (
    <button
      type="button"
      className="csv-button"
      onClick={() => {
        const link = document.createElement("a");
        link.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
        link.download = filename;
        document.body.append(link);
        link.click();
        setTimeout(() => {
          URL.revokeObjectURL(link.href);
          link.remove();
        }, 1000);
      }}
    >
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19h14" /></svg>
      {label}
    </button>
  );
}
