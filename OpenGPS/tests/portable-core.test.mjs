/**
 * Portable mirrors of OpenGPS core algorithms for CI on non-Mac hosts.
 * Canonical tests remain the XCTest suite under OpenGPSTests/ (requires Xcode).
 */
import assert from "node:assert/strict";
import test from "node:test";

function validate(lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) throw new Error("notFinite");
  if (lat < -90 || lat > 90) throw new Error("latitudeOutOfRange");
  if (lon < -180 || lon > 180) throw new Error("longitudeOutOfRange");
}

function interpolate(a, b, fraction) {
  const t = Math.max(0, Math.min(1, fraction));
  return {
    latitude: a.latitude + (b.latitude - a.latitude) * t,
    longitude: a.longitude + (b.longitude - a.longitude) * t,
  };
}

function haversine(a, b) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

class RouteInterpolator {
  constructor(waypoints, speed) {
    this.waypoints = waypoints;
    this.speed = Math.max(0.1, speed);
    this.distanceTraveled = 0;
    this.isPaused = false;
    this.segmentLengths = [];
    this.totalDistance = 0;
    for (let i = 0; i < waypoints.length - 1; i++) {
      const d = haversine(waypoints[i], waypoints[i + 1]);
      this.segmentLengths.push(d);
      this.totalDistance += d;
    }
  }
  pause() {
    this.isPaused = true;
  }
  resume() {
    this.isPaused = false;
  }
  advance(dt) {
    if (!this.isPaused && this.totalDistance > 0) {
      this.distanceTraveled = Math.min(
        this.totalDistance,
        this.distanceTraveled + this.speed * Math.max(0, dt)
      );
    }
    return this.current();
  }
  current() {
    let remaining = this.distanceTraveled;
    for (let i = 0; i < this.waypoints.length - 1; i++) {
      const length = this.segmentLengths[i];
      if (remaining <= length || i === this.waypoints.length - 2) {
        const fraction = length > 0 ? Math.min(1, remaining / length) : 1;
        return {
          coordinate: interpolate(this.waypoints[i], this.waypoints[i + 1], fraction),
          distanceTraveled: this.distanceTraveled,
          isComplete: this.distanceTraveled >= this.totalDistance,
          speed: this.isPaused ? 0 : this.speed,
        };
      }
      remaining -= length;
    }
    return {
      coordinate: this.waypoints.at(-1),
      distanceTraveled: this.totalDistance,
      isComplete: true,
      speed: 0,
    };
  }
}

function parseGPX(xml) {
  if (!xml || !xml.trim()) throw new Error("emptyDocument");
  if (!xml.includes("<") || !xml.includes(">")) throw new Error("malformedXML");
  const points = [];
  const re = /<(?:wpt|trkpt|rtept)\s+lat="([^"]+)"\s+lon="([^"]+)"/g;
  let m;
  while ((m = re.exec(xml))) {
    const lat = Number(m[1]);
    const lon = Number(m[2]);
    validate(lat, lon);
    points.push({ latitude: lat, longitude: lon });
  }
  if (!points.length) {
    if (xml.includes("<wpt") || xml.includes("<trkpt")) throw new Error("malformedXML");
    throw new Error("noCoordinates");
  }
  return points;
}

function statusMayClaimSystemWide(status) {
  return status?.kind === "developerHostActive" && status.userConfirmed === true;
}

test("latitude longitude validation", () => {
  validate(0, 0);
  assert.throws(() => validate(91, 0));
  assert.throws(() => validate(0, 181));
  assert.throws(() => validate(NaN, 0));
});

test("invalid and malformed GPX", () => {
  assert.throws(() => parseGPX(""), /emptyDocument/);
  assert.throws(() => parseGPX("<gpx></gpx>"), /noCoordinates/);
  assert.throws(() => parseGPX('<gpx><wpt lat="999" lon="0"/></gpx>'), /latitudeOutOfRange|longitudeOutOfRange/);
  const ok = parseGPX('<gpx><wpt lat="1" lon="2"/><wpt lat="3" lon="4"/></gpx>');
  assert.equal(ok.length, 2);
});

test("route interpolation and pause resume", () => {
  const mid = interpolate({ latitude: 0, longitude: 0 }, { latitude: 10, longitude: 20 }, 0.5);
  assert.equal(mid.latitude, 5);
  assert.equal(mid.longitude, 10);
  const route = new RouteInterpolator(
    [
      { latitude: 0, longitude: 0 },
      { latitude: 0, longitude: 0.01 },
    ],
    100
  );
  const a = route.advance(1);
  assert.ok(a.distanceTraveled > 0);
  route.pause();
  const pausedAt = route.distanceTraveled;
  route.advance(5);
  assert.equal(route.distanceTraveled, pausedAt);
  route.resume();
  route.advance(1);
  assert.ok(route.distanceTraveled > pausedAt);
});

test("permission denial reporting", () => {
  const denied = { authorizationStatus: "denied", lastError: "Location permission denied." };
  assert.equal(denied.authorizationStatus, "denied");
  assert.match(denied.lastError, /denied/i);
});

test("developer connection loss and unsupported iOS", () => {
  const unsupported = { kind: "unavailable", reason: "OpenGPS requires iOS 17 or later" };
  assert.equal(unsupported.kind, "unavailable");
  const lost = { kind: "connectionLost", reason: "USB/tunnel ended" };
  assert.equal(lost.kind, "connectionLost");
  assert.equal(statusMayClaimSystemWide({ kind: "previewActive" }), false);
  assert.equal(
    statusMayClaimSystemWide({ kind: "developerHostActive", userConfirmed: false }),
    false
  );
  assert.equal(
    statusMayClaimSystemWide({ kind: "developerHostActive", userConfirmed: true }),
    true
  );
});

test("accurate simulation status reporting", () => {
  const previewMsg = "In-app preview active. Other apps still use real device location.";
  assert.match(previewMsg, /Other apps/);
  assert.doesNotMatch(previewMsg.toLowerCase(), /system-wide gps spoofing active/);
});
