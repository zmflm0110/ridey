"use client";

export function CsvButton({ filename, csv, label }: { filename: string; csv: string; label: string }) {
  return (
    <button
      type="button"
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
      {label}
    </button>
  );
}
