import { normalizeBike } from "@/lib/priority";

export const FIELD_STATUSES = ["멀쩡함", "타이어", "체인·기어", "안장·핸들", "브레이크", "기타 고장"] as const;

export type FieldStatus = (typeof FIELD_STATUSES)[number];

export type FieldDraft = {
  at: string;
  station: string | null;
  bike: string;
  status: FieldStatus;
  note: string | null;
  lat: number | null;
  lon: number | null;
  photo: string | null;
};

const queueKey = "survey_queue";

export function seoulPoint(lat: number, lon: number): { lat: number; lon: number } | null {
  if (lat < 33 || lat > 39 || lon < 124 || lon > 132) return null;
  return { lat, lon };
}

export function photoName(bytes = crypto.getRandomValues(new Uint8Array(8))): string {
  return `${[...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("")}.jpg`;
}

export function surveyPayload(draft: FieldDraft, photo: string | null) {
  return {
    at: draft.at,
    station: draft.station ? draft.station.slice(0, 10) : null,
    bike: draft.bike,
    status: draft.status,
    note: draft.note ? draft.note.slice(0, 200) : null,
    lat: draft.lat,
    lon: draft.lon,
    photo,
  };
}

function isDraft(value: unknown): value is FieldDraft {
  if (!value || typeof value !== "object") return false;
  const row = value as FieldDraft;
  return typeof row.at === "string" && typeof row.bike === "string" && FIELD_STATUSES.includes(row.status);
}

export function readQueue(storage: Pick<Storage, "getItem">): FieldDraft[] {
  try {
    const parsed = JSON.parse(storage.getItem(queueKey) || "[]");
    return Array.isArray(parsed) ? parsed.filter(isDraft) : [];
  } catch {
    return [];
  }
}

export function writeQueue(storage: Pick<Storage, "setItem">, queue: FieldDraft[]): boolean {
  try {
    storage.setItem(queueKey, JSON.stringify(queue));
    return true;
  } catch {
    return false;
  }
}

export function makeDraft(input: {
  at: string;
  station: string | null;
  rawBike: string;
  status: FieldStatus;
  note: string;
  lat: number | null;
  lon: number | null;
  photo: string | null;
}): FieldDraft | null {
  const bike = normalizeBike(input.rawBike);
  if (!bike) return null;
  const point = input.lat != null && input.lon != null ? seoulPoint(input.lat, input.lon) : null;
  return {
    at: input.at,
    station: input.station,
    bike,
    status: input.status,
    note: input.note.trim() || null,
    lat: point?.lat ?? null,
    lon: point?.lon ?? null,
    photo: input.photo,
  };
}

export async function shrinkPhoto(file: Blob, max = 1280, quality = 0.7): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => {
      const element = new Image();
      element.onload = () => resolve(element);
      element.onerror = () => reject(new Error("photo"));
      element.src = url;
    });
    const scale = Math.min(1, max / Math.max(image.naturalWidth, image.naturalHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
    canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
    canvas.getContext("2d")?.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", quality);
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function dataUrlToBlob(dataUrl: string): Blob {
  const [header, data] = dataUrl.split(",");
  const mime = /data:(.*?);/.exec(header)?.[1] || "image/jpeg";
  const binary = atob(data);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return new Blob([bytes], { type: mime });
}
