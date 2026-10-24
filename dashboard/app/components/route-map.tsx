"use client";

import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";
import type { LatLon } from "@/lib/route";

export function RouteMap({ start, stops }: { start: (LatLon & { name: string }) | null; stops: (LatLon & { name: string })[] }) {
  const host = useRef<HTMLDivElement>(null);
  const mapRef = useRef<import("leaflet").Map | null>(null);
  const layerRef = useRef<import("leaflet").LayerGroup | null>(null);
  const ticket = useRef(0);

  useEffect(() => {
    const node = host.current;
    if (!node) return;
    const current = ++ticket.current;
    let cancelled = false;
    (async () => {
      const leaflet = await import("leaflet");
      const L = leaflet.default ?? leaflet;
      if (cancelled || current !== ticket.current || !node) return;
      if (!mapRef.current) {
        mapRef.current = L.map(node).setView([37.55, 126.99], 11);
        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
          maxZoom: 18,
          attribution: "© OpenStreetMap",
        }).addTo(mapRef.current);
      }
      const map = mapRef.current;
      layerRef.current?.remove();
      const layer = L.layerGroup().addTo(map);
      layerRef.current = layer;
      if (start && stops.length) {
        const path = [start, ...stops].map((point) => [point.lat, point.lon] as [number, number]);
        L.polyline(path, { color: "#FFFFFF", weight: 7, opacity: 0.9 }).addTo(layer);
        L.polyline(path, { color: "#111317", weight: 3, opacity: 1, dashArray: "6 6" }).addTo(layer);
        stops.forEach((stop, index) => {
          L.marker([stop.lat, stop.lon], {
            icon: L.divIcon({ className: "route-num", html: String(index + 1), iconSize: [22, 22] }),
          }).addTo(layer);
        });
        map.fitBounds(L.latLngBounds(path).pad(0.2), { maxZoom: 14 });
      }
      map.invalidateSize();
    })();
    return () => {
      cancelled = true;
    };
  }, [start, stops]);

  useEffect(() => () => {
    mapRef.current?.remove();
    mapRef.current = null;
  }, []);

  return <div ref={host} className="map-frame" />;
}
