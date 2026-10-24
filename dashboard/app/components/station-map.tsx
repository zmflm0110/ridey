"use client";

import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";
import type { Bike } from "@/lib/priority";

export type MapGroup = {
  id: string;
  name: string;
  lat: number;
  lon: number;
  bikes: Bike[];
  red: boolean;
};

function popupNode(group: MapGroup): HTMLElement {
  const node = document.createElement("div");
  const title = document.createElement("strong");
  title.textContent = group.name;
  node.append(title);
  for (const bike of group.bikes) {
    const line = document.createElement("div");
    line.textContent = `${bike.bike} · ${bike.chain}명 연속`;
    node.append(line);
  }
  return node;
}

export function StationMap({ groups }: { groups: MapGroup[] }) {
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
      for (const group of groups) {
        const marker = L.circleMarker([group.lat, group.lon], {
          radius: 5 + 2 * group.bikes.length,
          color: group.red ? "#FF4F1F" : "#FF9A73",
          weight: 1.5,
          fillOpacity: 0.55,
        });
        marker.bindPopup(popupNode(group));
        marker.addTo(layer);
      }
      if (groups.length) {
        const bounds = L.latLngBounds(groups.map((group) => [group.lat, group.lon] as [number, number]));
        map.fitBounds(bounds.pad(0.2), { maxZoom: 14 });
      }
      map.invalidateSize();
    })();
    return () => {
      cancelled = true;
    };
  }, [groups]);

  useEffect(() => {
    return () => {
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  return <div ref={host} className="map-frame" />;
}
