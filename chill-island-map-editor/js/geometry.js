/* CHILL ISLAND MAP EDITOR - 2D polygon & spline helpers (map space) */
(function (global) {
  'use strict';

  var N = global.CHILL.Noise;
  var clamp = N.clamp;
  var lerp = N.lerp;
  var smoothstep = N.smoothstep;

  function pt(p) { return { x: p[0], z: p[1] }; }
  function arr(p) { return [p.x, p.z]; }

  function polygonBBox(points) {
    var b = { minX: Infinity, minZ: Infinity, maxX: -Infinity, maxZ: -Infinity };
    for (var i = 0; i < points.length; i++) {
      var p = points[i];
      if (p[0] < b.minX) b.minX = p[0];
      if (p[0] > b.maxX) b.maxX = p[0];
      if (p[1] < b.minZ) b.minZ = p[1];
      if (p[1] > b.maxZ) b.maxZ = p[1];
    }
    return b;
  }

  function pointInPolygon(x, z, points) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      var xi = points[i][0], zi = points[i][1];
      var xj = points[j][0], zj = points[j][1];
      if (((zi > z) !== (zj > z)) &&
          (x < (xj - xi) * (z - zi) / ((zj - zi) || 1e-12) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  function distToSegmentSq(px, pz, ax, az, bx, bz) {
    var abx = bx - ax, abz = bz - az;
    var len2 = abx * abx + abz * abz;
    var t = len2 > 1e-12 ? ((px - ax) * abx + (pz - az) * abz) / len2 : 0;
    t = clamp(t, 0, 1);
    var dx = px - (ax + abx * t), dz = pz - (az + abz * t);
    return { d2: dx * dx + dz * dz, t: t, x: ax + abx * t, z: az + abz * t };
  }

  function pointSegmentInfo(px, pz, a, b) {
    return distToSegmentSq(px, pz, a.x, a.z, b.x, b.z);
  }

  function distToSegment(px, pz, a, b) {
    return Math.sqrt(distToSegmentSq(px, pz, a.x, a.z, b.x, b.z).d2);
  }

  function polylineDistance(px, pz, points) {
    var best = 1e18;
    for (var i = 0; i < points.length - 1; i++) {
      var d = distToSegmentSq(px, pz, points[i][0], points[i][1], points[i + 1][0], points[i + 1][1]).d2;
      if (d < best) best = d;
    }
    return Math.sqrt(best);
  }

  /* Signed distance to polygon: positive inside, negative outside. */
  function polygonInfo(x, z, points) {
    var inside = pointInPolygon(x, z, points);
    var best = 1e18;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      var r = distToSegmentSq(x, z, points[j][0], points[j][1], points[i][0], points[i][1]);
      if (r.d2 < best) best = r.d2;
    }
    var d = Math.sqrt(best);
    return { inside: inside, dist: d, signed: inside ? d : -d };
  }

  function polygonArea(points) {
    var a = 0;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      a += points[j][0] * points[i][1] - points[i][0] * points[j][1];
    }
    return Math.abs(a * 0.5);
  }

  function polygonCentroid(points) {
    var a = 0, cx = 0, cz = 0;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      var cross = points[j][0] * points[i][1] - points[i][0] * points[j][1];
      a += cross;
      cx += (points[j][0] + points[i][0]) * cross;
      cz += (points[j][1] + points[i][1]) * cross;
    }
    if (Math.abs(a) < 1e-9) {
      var sx = 0, sz = 0;
      for (var k = 0; k < points.length; k++) { sx += points[k][0]; sz += points[k][1]; }
      return [sx / points.length, sz / points.length];
    }
    a *= 0.5;
    return [cx / (6 * a), cz / (6 * a)];
  }

  function polygonSize(points) {
    var b = polygonBBox(points);
    return [b.maxX - b.minX, b.maxZ - b.minZ];
  }

  function movePolygon(points, dx, dz) {
    for (var i = 0; i < points.length; i++) {
      points[i][0] += dx;
      points[i][1] += dz;
    }
  }

  function scalePolygon(points, cx, cz, sx, sz) {
    for (var i = 0; i < points.length; i++) {
      points[i][0] = cx + (points[i][0] - cx) * sx;
      points[i][1] = cz + (points[i][1] - cz) * sz;
    }
  }

  function rotateAround(x, z, cx, cz, ang) {
    var c = Math.cos(ang), s = Math.sin(ang);
    var dx = x - cx, dz = z - cz;
    return [cx + dx * c - dz * s, cz + dx * s + dz * c];
  }

  function ellipsePolygon(cx, cz, rx, rz, segments, rotation) {
    segments = Math.max(6, segments || 24);
    rotation = rotation || 0;
    var pts = [];
    for (var i = 0; i < segments; i++) {
      var a = (i / segments) * Math.PI * 2;
      pts.push(rotateAround(cx + Math.cos(a) * rx, cz + Math.sin(a) * rz, cx, cz, rotation));
    }
    return pts;
  }

  function roundedRectPolygon(x0, z0, x1, z1, radius, cornerSegments) {
    radius = Math.max(0.001, radius || 1);
    cornerSegments = Math.max(3, cornerSegments || 8);
    var pts = [];
    var corners = [
      { cx: x1 - radius, cz: z0 + radius, a0: -Math.PI / 2, a1: 0 },
      { cx: x1 - radius, cz: z1 - radius, a0: 0, a1: Math.PI / 2 },
      { cx: x0 + radius, cz: z1 - radius, a0: Math.PI / 2, a1: Math.PI },
      { cx: x0 + radius, cz: z0 + radius, a0: Math.PI, a1: Math.PI * 1.5 }
    ];
    for (var c = 0; c < corners.length; c++) {
      var k = corners[c];
      for (var i = 0; i <= cornerSegments; i++) {
        var a = lerp(k.a0, k.a1, i / cornerSegments);
        pts.push([k.cx + Math.cos(a) * radius, k.cz + Math.sin(a) * radius]);
      }
    }
    return pts;
  }

  function catmullRom(points, spacing) {
    spacing = spacing || 6;
    if (!points || points.length === 0) return [];
    if (points.length === 1) return [[points[0][0], points[0][1]]];
    var out = [];
    for (var i = 0; i < points.length - 1; i++) {
      var p0 = points[i - 1] || points[i];
      var p1 = points[i];
      var p2 = points[i + 1];
      var p3 = points[i + 2] || p2;
      var len = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]);
      var steps = clamp(Math.ceil(len / spacing), 4, 64);
      for (var s = 0; s < steps; s++) {
        var t = s / steps;
        var t2 = t * t, t3 = t2 * t;
        var x = 0.5 * ((2 * p1[0]) +
          (-p0[0] + p2[0]) * t +
          (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
          (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3);
        var z = 0.5 * ((2 * p1[1]) +
          (-p0[1] + p2[1]) * t +
          (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
          (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3);
        out.push([x, z]);
      }
    }
    out.push([points[points.length - 1][0], points[points.length - 1][1]]);
    return out;
  }

  function polylineLength(points) {
    var total = 0;
    for (var i = 1; i < points.length; i++) {
      total += Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]);
    }
    return total;
  }

  function perimeterSamples(points, step, closed) {
    step = step || 8;
    var out = [];
    var n = points.length;
    var count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      var a = points[i], b = points[(i + 1) % n];
      var len = Math.hypot(b[0] - a[0], b[1] - a[1]);
      var steps = Math.max(1, Math.ceil(len / step));
      for (var s = 0; s < steps; s++) {
        var t = s / steps;
        out.push([lerp(a[0], b[0], t), lerp(a[1], b[1], t)]);
      }
    }
    if (!closed) out.push([points[n - 1][0], points[n - 1][1]]);
    return out;
  }

  function nearestEdgeIndex(x, z, points, closed) {
    var best = 1e18, bestI = 0;
    var n = points.length;
    var count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      var a = points[i], b = points[(i + 1) % n];
      var r = distToSegmentSq(x, z, a[0], a[1], b[0], b[1]);
      if (r.d2 < best) { best = r.d2; bestI = i; }
    }
    return bestI;
  }

  function insertPointOnEdge(points, x, z, closed) {
    var i = nearestEdgeIndex(x, z, points, closed);
    points.splice(i + 1, 0, [x, z]);
    return i + 1;
  }

  function segmentIntersection(a, b, c, d) {
    var r0 = b[0] - a[0], r1 = b[1] - a[1];
    var s0 = d[0] - c[0], s1 = d[1] - c[1];
    var den = r0 * s1 - r1 * s0;
    if (Math.abs(den) < 1e-9) return null;
    var t = ((c[0] - a[0]) * s1 - (c[1] - a[1]) * s0) / den;
    var u = ((c[0] - a[0]) * r1 - (c[1] - a[1]) * r0) / den;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return [a[0] + t * r0, a[1] + t * r1];
    }
    return null;
  }

  function uniqueId(base, used) {
    var id = String(base || 'item').trim() || 'item';
    id = id.replace(/[^a-zA-Z0-9_\-]+/g, '_');
    if (!used.has(id)) { used.add(id); return id; }
    var i = 2;
    while (used.has(id + '_' + i)) i++;
    used.add(id + '_' + i);
    return id + '_' + i;
  }

  function deepClone(v) { return JSON.parse(JSON.stringify(v)); }

  function round(v, p) {
    var m = Math.pow(10, p == null ? 3 : p);
    return Math.round(v * m) / m;
  }

  function dist2(x1, z1, x2, z2) { return Math.hypot(x2 - x1, z2 - z1); }

  global.CHILL.Geo = {
    clamp: clamp,
    lerp: lerp,
    smoothstep: smoothstep,
    polygonBBox: polygonBBox,
    pointInPolygon: pointInPolygon,
    polygonInfo: polygonInfo,
    polygonArea: polygonArea,
    polygonCentroid: polygonCentroid,
    polygonSize: polygonSize,
    movePolygon: movePolygon,
    scalePolygon: scalePolygon,
    rotateAround: rotateAround,
    ellipsePolygon: ellipsePolygon,
    roundedRectPolygon: roundedRectPolygon,
    catmullRom: catmullRom,
    polylineLength: polylineLength,
    perimeterSamples: perimeterSamples,
    nearestEdgeIndex: nearestEdgeIndex,
    insertPointOnEdge: insertPointOnEdge,
    segmentIntersection: segmentIntersection,
    pointSegmentInfo: pointSegmentInfo,
    distToSegment: distToSegment,
    polylineDistance: polylineDistance,
    uniqueId: uniqueId,
    deepClone: deepClone,
    round: round,
    dist2: dist2
  };
})(window);
