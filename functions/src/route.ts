export interface Point {
  lat: number;
  lng: number;
}

/**
 * Generates a smooth, slightly curved route between two points.
 * (A real app would call a Directions API; this keeps the demo free.)
 */
export function generateRoute(from: Point, to: Point, steps = 30): Point[] {
  const dLat = to.lat - from.lat;
  const dLng = to.lng - from.lng;
  // Perpendicular offset gives the polyline a natural bend.
  const bend = 0.15;
  const points: Point[] = [];
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const curve = Math.sin(Math.PI * t) * bend;
    points.push({
      lat: round(from.lat + dLat * t - dLng * curve),
      lng: round(from.lng + dLng * t + dLat * curve),
    });
  }
  return points;
}

/** Remaining minutes when the courier moves one point per [intervalSec]. */
export function etaMinutes(remainingPoints: number, intervalSec: number): number {
  return Math.max(1, Math.ceil((remainingPoints * intervalSec) / 60));
}

/** Haversine distance in km. */
export function distanceKm(a: Point, b: Point): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function round(v: number): number {
  return Math.round(v * 1e6) / 1e6;
}
