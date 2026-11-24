/* CHILL ISLAND MAP EDITOR - heightfield generator (coast, zones, edits, rivers) */
(function (global) {
  'use strict';

  var Geo = global.CHILL.Geo;
  var Noise = global.CHILL.Noise;
  var clamp = Noise.clamp;
  var lerp = Noise.lerp;
  var smoothstep = Noise.smoothstep;
  var smootherstep = Noise.smootherstep;

  var RES = 192;
  var SEABED = -9;

  function hexToRgb(hex) {
    var h = hex.replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
  }

  function srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }

  function mix3(a, b, t) {
    return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
  }

  var PAL = {
    grass: hexToRgb('#5f7a3c'),
    grassLight: hexToRgb('#7c8e4d'),
    grassDark: hexToRgb('#4a6333'),
    pine: hexToRgb('#355c35'),
    pineDark: hexToRgb('#294b2c'),
    pineLight: hexToRgb('#4a6b38'),
    decid: hexToRgb('#527a3a'),
    decidDark: hexToRgb('#446b31'),
    decidLight: hexToRgb('#678b43'),
    farm: hexToRgb('#9a8b4b'),
    farmLight: hexToRgb('#b2a15c'),
    farmDark: hexToRgb('#83753c'),
    swamp: hexToRgb('#4d5a35'),
    swampDark: hexToRgb('#3e4b2c'),
    swampWet: hexToRgb('#586440'),
    camp: hexToRgb('#82684a'),
    campLight: hexToRgb('#957c5c'),
    ruins: hexToRgb('#807d72'),
    mountain: hexToRgb('#77736a'),
    rock: hexToRgb('#7b776e'),
    rockLight: hexToRgb('#948e82'),
    sand: hexToRgb('#cbb787'),
    sandWet: hexToRgb('#9c8d67'),
    mud: hexToRgb('#6d5a3c'),
    seabedShallow: hexToRgb('#3f6660'),
    seabedDeep: hexToRgb('#24444d'),
    lakeBed: hexToRgb('#2d5557'),
    snow: hexToRgb('#c9c8c0')
  };

  function TerrainBuilder(data) {
    this.data = data;
    this.res = RES;
    this.stepX = data.map.size.width / RES;
    this.stepZ = data.map.size.length / RES;
    this.n = RES + 1;
    this.nv = this.n * this.n;
    this.noise = new Noise.Noise2D(data.map.seed || 1);
    this.riverMask = new Float32Array(this.nv);
    this.zoneGrid = new Int16Array(this.nv);
    this.build();
  }

  TerrainBuilder.prototype.build = function () {
    var data = this.data;
    var width = data.map.size.width;
    var length = data.map.size.length;
    var terrain = data.terrain;
    var n = this.n;
    var stepX = width / this.res;
    var stepZ = length / this.res;
    this.stepX = stepX;
    this.stepZ = stepZ;
    this.coast = terrain.coast.points;
    this.coastBBox = Geo.polygonBBox(this.coast);

    this.zoneDefs = (data.zones || []).map(function (z) {
      return {
        zone: z,
        poly: z.points,
        bbox: Geo.polygonBBox(z.points),
        priority: global.CHILL.Data.priorityOf(z.type)
      };
    }).sort(function (a, b) { return a.priority - b.priority; });

    this.lakeDefs = this.zoneDefs.filter(function (d) { return d.zone.type === 'lake'; });
    this.editDefs = terrain.edits || [];

    var natural = new Float32Array(this.nv);
    var zoneGrid = new Int16Array(this.nv);
    var zonePri = new Float32Array(this.nv);
    zonePri.fill(-1);

    for (var j = 0; j < n; j++) {
      var z = j * stepZ;
      for (var i = 0; i < n; i++) {
        var x = i * stepX;
        var h = this.baseHeight(x, z);
        var topZone = -1, topPri = -1;

        for (var zd = 0; zd < this.zoneDefs.length; zd++) {
          var def = this.zoneDefs[zd];
          var bb = def.bbox;
          if (x < bb.minX - 2 || x > bb.maxX + 2 || z < bb.minZ - 2 || z > bb.maxZ + 2) continue;
          var info = Geo.polygonInfo(x, z, def.poly);
          if (!info.inside) continue;

          var zone = def.zone;
          var minDim = Math.max(10, Math.min(zone.size[0], zone.size[1]));
          var edge = Math.max(3, minDim * 0.18);
          var insideF = smoothstep(0, edge, info.dist);

          if (zone.type === 'lake') {
            var wl = zone.waterLevel != null ? zone.waterLevel : terrain.waterLevel + 0.7;
            var shoreWidth = Math.max(10, minDim * 0.22);
            var f = smoothstep(0, shoreWidth, info.dist);
            var depth = clamp(2.4 + minDim * 0.012, 2.4, 8);
            var target = wl - 0.6 - depth * clamp(info.dist / (minDim * 0.45), 0, 1);
            if (h > target) h = lerp(h, target, f);
          } else if (zone.type === 'swamp') {
            var swl = zone.waterLevel != null ? zone.waterLevel : terrain.waterLevel + 0.4;
            var targetSw = Math.min(h, swl + 0.9);
            h = lerp(h, targetSw, insideF * 0.85);
          } else if (zone.type === 'farm') {
            h = lerp(h, terrain.baseHeight * 0.72, insideF * 0.62);
          } else if (zone.type === 'camp') {
            h = lerp(h, terrain.baseHeight * 0.82, insideF * 0.5);
          } else if (zone.type === 'ruins') {
            h = lerp(h, Math.max(terrain.baseHeight, h * 0.9), insideF * 0.2);
          } else if (zone.type === 'mountain') {
            h += terrain.hillStrength * 0.28 * insideF;
          }

          if (def.priority > topPri) { topPri = def.priority; topZone = zd; }
        }

        for (var e = 0; e < this.editDefs.length; e++) {
          var edit = this.editDefs[e];
          var dx = x - edit.center[0], dz = z - edit.center[1];
          var dist = Math.sqrt(dx * dx + dz * dz);
          if (dist > edit.radius) continue;
          var t = clamp(1 - dist / edit.radius, 0, 1);
          var inf = smoothstep(0, 1, t);
          inf = Math.pow(inf, 0.65 + (1 - edit.falloff) * 1.4);
          if (edit.type === 'hill') {
            h += edit.height * inf;
          } else if (edit.type === 'depression') {
            h -= Math.abs(edit.height) * inf;
          } else if (edit.type === 'plateau') {
            h = lerp(h, edit.height, inf * 0.94);
          } else if (edit.type === 'cliff') {
            h += Math.abs(edit.height) * Math.pow(inf, 0.45);
          }
        }

        h = clamp(h, SEABED - 20, data.map.size.maxHeight);
        natural[j * n + i] = h;
        zoneGrid[j * n + i] = topZone;
        zonePri[j * n + i] = topPri;
      }
    }

    this.natural = natural;
    this.zoneGrid = zoneGrid;

    this.buildRivers(natural);

    var finalGrid = new Float32Array(natural);
    var riverMask = new Float32Array(this.nv);
    for (var r = 0; r < this.riverData.length; r++) {
      this.carveRiver(this.riverData[r], finalGrid, riverMask);
    }
    this.grid = finalGrid;
    this.riverMask = riverMask;

    this.buildColors();
  };

  TerrainBuilder.prototype.baseHeight = function (x, z) {
    var data = this.data;
    var width = data.map.size.width;
    var length = data.map.size.length;
    var terrain = data.terrain;
    var info = Geo.polygonInfo(x, z, this.coast);
    var signed = info.signed;
    var land = smoothstep(0, terrain.coastBlend, signed);

    var fx = x / Math.max(1, width);
    var fz = z / Math.max(1, length);
    var broad = this.noise.fbm(x * 0.0018 + 11.3, z * 0.0018 - 7.1, 4, 2.0, 0.52);
    var detail = this.noise.fbm(x * 0.008 + 3.7, z * 0.008 + 9.2, 4, 2.1, 0.5);
    var micro = this.noise.fbm(x * 0.021 - 4.1, z * 0.021 + 2.4, 3, 2.2, 0.5);

    var h = terrain.baseHeight;
    h += broad * terrain.hillStrength * 0.46;
    h += detail * terrain.hillStrength * terrain.roughness * 0.95;
    h += micro * terrain.hillStrength * terrain.roughness * 0.28;
    h += terrain.hillStrength * 0.16 * land;
    h += Math.sin((fx + fz) * Math.PI * 1.3) * terrain.hillStrength * 0.035;

    return lerp(SEABED, h, land);
  };

  TerrainBuilder.prototype.smoothHeights = function (arr, radius, passes) {
    var out = arr.slice();
    for (var p = 0; p < passes; p++) {
      var tmp = out.slice();
      for (var i = 0; i < out.length; i++) {
        var sum = 0, count = 0;
        for (var k = -radius; k <= radius; k++) {
          var idx = i + k;
          if (idx < 0 || idx >= out.length) continue;
          sum += tmp[idx];
          count++;
        }
        out[i] = sum / count;
      }
    }
    return out;
  };

  TerrainBuilder.prototype.buildRivers = function (natural) {
    var data = this.data;
    var terrain = data.terrain;
    var out = [];
    for (var r = 0; r < data.rivers.length; r++) {
      var river = data.rivers[r];
      if (!river.points || river.points.length < 2) continue;
      var pts = Geo.catmullRom(river.points, 5);
      if (pts.length < 2) continue;
      var heights = [];
      for (var i = 0; i < pts.length; i++) {
        heights.push(this.sampleGrid(natural, pts[i][0], pts[i][1]));
      }
      var radius = 1 + Math.round(river.smoothness * 5);
      var passes = 1 + Math.round(river.smoothness * 4);
      var smoothed = this.smoothHeights(heights, radius, passes);
      var waterY = [];
      var accum = [0];
      for (var j = 0; j < pts.length; j++) {
        waterY.push(river.autoWater ? smoothed[j] - 0.12 : river.waterHeight);
        if (j > 0) {
          accum.push(accum[j - 1] + Math.hypot(pts[j][0] - pts[j - 1][0], pts[j][1] - pts[j - 1][1]));
        }
      }
      if (river.autoWater) {
        var sum = 0;
        for (var k = 0; k < waterY.length; k++) sum += waterY[k];
        river.waterHeight = Geo.round(sum / waterY.length, 3);
      }
      var inner = Math.max(0.35, river.width * 0.5);
      var effBank = Math.max(river.bankWidth, river.depth * 2.2);
      var bbox = { minX: 1e9, minZ: 1e9, maxX: -1e9, maxZ: -1e9 };
      var pad = inner + effBank + 4;
      for (var b = 0; b < pts.length; b++) {
        if (pts[b][0] < bbox.minX) bbox.minX = pts[b][0];
        if (pts[b][0] > bbox.maxX) bbox.maxX = pts[b][0];
        if (pts[b][1] < bbox.minZ) bbox.minZ = pts[b][1];
        if (pts[b][1] > bbox.maxZ) bbox.maxZ = pts[b][1];
      }
      bbox.minX -= pad; bbox.maxX += pad; bbox.minZ -= pad; bbox.maxZ += pad;
      out.push({
        river: river,
        index: r,
        pts: pts,
        naturalH: heights,
        smoothedH: smoothed,
        waterY: waterY,
        accum: accum,
        inner: inner,
        effBank: effBank,
        bbox: bbox
      });
    }
    this.riverData = out;
  };

  TerrainBuilder.prototype.carveRiver = function (rd, grid, mask) {
    var river = rd.river;
    var n = this.n;
    var i0 = clamp(Math.floor(rd.bbox.minX / this.stepX), 0, n - 1);
    var i1 = clamp(Math.ceil(rd.bbox.maxX / this.stepX), 0, n - 1);
    var j0 = clamp(Math.floor(rd.bbox.minZ / this.stepZ), 0, n - 1);
    var j1 = clamp(Math.ceil(rd.bbox.maxZ / this.stepZ), 0, n - 1);
    var inner = rd.inner;
    var effBank = rd.effBank;
    var outer = inner + effBank;
    var depth = river.depth;
    var pts = rd.pts;
    var waterY = rd.waterY;
    var cross = river.crossSection;
    var bankT = river.bankTransition;
    var bestDist, bestSeg, bestT, bestPx, bestPz;

    for (var j = j0; j <= j1; j++) {
      var z = j * this.stepZ;
      for (var i = i0; i <= i1; i++) {
        var x = i * this.stepX;
        bestDist = 1e18; bestSeg = 0; bestT = 0; bestPx = x; bestPz = z;
        for (var s = 0; s < pts.length - 1; s++) {
          var r = Geo.pointSegmentInfo(x, z, { x: pts[s][0], z: pts[s][1] }, { x: pts[s + 1][0], z: pts[s + 1][1] });
          if (r.d2 < bestDist) {
            bestDist = r.d2;
            bestSeg = s;
            bestT = r.t;
            bestPx = r.x;
            bestPz = r.z;
          }
        }
        var dist = Math.sqrt(bestDist);
        if (dist > outer) continue;
        var wy = lerp(waterY[bestSeg], waterY[bestSeg + 1], bestT);
        var idx = j * n + i;
        var mud = 0;

        if (dist <= inner) {
          var t = 1 - clamp(dist / inner, 0, 1);
          var prof;
          if (cross === 'round_u') prof = Math.sin(t * Math.PI * 0.5);
          else if (cross === 'flat_bottom') prof = smoothstep(0, 0.82, t);
          else if (cross === 'parabolic') prof = t * t;
          else if (cross === 'v_shallow') prof = Math.pow(t, 0.65);
          else prof = smootherstep(0, 1, t);
          var channelH = wy - depth * prof;
          if (grid[idx] > channelH) grid[idx] = channelH;
          mud = 0.9 + 0.1 * prof;
        } else if (dist < outer) {
          var bT = 1 - (dist - inner) / effBank;
          var f;
          if (bankT === 'linear') f = bT;
          else if (bankT === 'cubic') f = bT * bT * bT * (bT * (bT * 6 - 15) + 10);
          else f = bT * bT * (3 - 2 * bT);
          if (grid[idx] > wy) grid[idx] = lerp(grid[idx], wy, f);
          mud = f * 0.85;
        }
        if (mud > mask[idx]) mask[idx] = mud;
      }
    }
  };

  TerrainBuilder.prototype.sampleGrid = function (grid, x, z) {
    var fx = clamp(x / this.stepX, 0, this.res - 1e-6);
    var fz = clamp(z / this.stepZ, 0, this.res - 1e-6);
    var x0 = Math.floor(fx), z0 = Math.floor(fz);
    var tx = fx - x0, tz = fz - z0;
    var x1 = Math.min(x0 + 1, this.res);
    var z1 = Math.min(z0 + 1, this.res);
    var n = this.n;
    var h00 = grid[z0 * n + x0];
    var h10 = grid[z0 * n + x1];
    var h01 = grid[z1 * n + x0];
    var h11 = grid[z1 * n + x1];
    return lerp(lerp(h00, h10, tx), lerp(h01, h11, tx), tz);
  };

  TerrainBuilder.prototype.heightAt = function (x, z) {
    return this.sampleGrid(this.grid, x, z);
  };

  TerrainBuilder.prototype.naturalHeightAt = function (x, z) {
    return this.sampleGrid(this.natural, x, z);
  };

  TerrainBuilder.prototype.normalAt = function (x, z) {
    var e = Math.max(2, this.stepX * 1.5);
    var hl = this.heightAt(x - e, z);
    var hr = this.heightAt(x + e, z);
    var hd = this.heightAt(x, z - e);
    var hu = this.heightAt(x, z + e);
    var nx = -(hr - hl);
    var nz = -(hu - hd);
    var ny = 2 * e;
    var len = Math.hypot(nx, ny, nz) || 1;
    return { x: nx / len, y: ny / len, z: nz / len };
  };

  TerrainBuilder.prototype.coastInfo = function (x, z) {
    return Geo.polygonInfo(x, z, this.coast);
  };

  TerrainBuilder.prototype.zoneAt = function (x, z) {
    var best = null, bestPri = -1;
    for (var i = this.zoneDefs.length - 1; i >= 0; i--) {
      var def = this.zoneDefs[i];
      var bb = def.bbox;
      if (x < bb.minX || x > bb.maxX || z < bb.minZ || z > bb.maxZ) continue;
      if (Geo.pointInPolygon(x, z, def.poly)) {
        if (def.priority > bestPri) { best = def.zone; bestPri = def.priority; }
      }
    }
    return best;
  };

  TerrainBuilder.prototype.lakeAt = function (x, z) {
    for (var i = 0; i < this.lakeDefs.length; i++) {
      var def = this.lakeDefs[i];
      var bb = def.bbox;
      if (x < bb.minX || x > bb.maxX || z < bb.minZ || z > bb.maxZ) continue;
      if (Geo.pointInPolygon(x, z, def.poly)) return def.zone;
    }
    return null;
  };

  TerrainBuilder.prototype.waterInfoAt = function (x, z) {
    var h = this.heightAt(x, z);
    if (h < this.data.terrain.waterLevel + 0.04) {
      return { kind: 'sea', level: this.data.terrain.waterLevel };
    }
    var lake = this.lakeAt(x, z);
    if (lake) {
      var level = lake.waterLevel != null ? lake.waterLevel : this.data.terrain.waterLevel + 0.7;
      if (level > h - 0.02) return { kind: 'lake', level: level, zone: lake };
    }
    for (var i = 0; i < this.riverData.length; i++) {
      var rd = this.riverData[i];
      var bb = rd.bbox;
      if (x < bb.minX || x > bb.maxX || z < bb.minZ || z > bb.maxZ) continue;
      var best = 1e18, bestSeg = 0, bestT = 0;
      for (var s = 0; s < rd.pts.length - 1; s++) {
        var r = Geo.pointSegmentInfo(x, z, { x: rd.pts[s][0], z: rd.pts[s][1] }, { x: rd.pts[s + 1][0], z: rd.pts[s + 1][1] });
        if (r.d2 < best) { best = r.d2; bestSeg = s; bestT = r.t; }
      }
      if (Math.sqrt(best) <= rd.inner) {
        var wy = lerp(rd.waterY[bestSeg], rd.waterY[bestSeg + 1], bestT);
        return { kind: 'river', level: wy, river: rd.river, index: i };
      }
    }
    return null;
  };

  TerrainBuilder.prototype.buildColors = function () {
    var colors = new Float32Array(this.nv * 3);
    var data = this.data;
    var terrain = data.terrain;
    var wl = terrain.waterLevel;
    var maxH = Math.max(10, data.map.size.maxHeight);
    var n = this.n;
    var noise = this.noise;
    var mix = mix3;

    for (var j = 0; j < n; j++) {
      var z = j * this.stepZ;
      for (var i = 0; i < n; i++) {
        var x = i * this.stepX;
        var idx = j * n + i;
        var h = this.grid[idx];
        var norm = this.normalAt(x, z);
        var slope = 1 - norm.y;
        var mottle = noise.fbm(x * 0.028, z * 0.028, 3, 2.0, 0.5) * 0.5 + 0.5;
        var zone = this.zoneGrid[idx] >= 0 ? data.zones[this.zoneGrid[idx]] : null;
        var c;

        if (h < wl - 0.35) {
          var t = clamp((h - (SEABED - 6)) / Math.max(1, (wl - (SEABED - 6))), 0, 1);
          c = mix(PAL.seabedDeep, PAL.seabedShallow, t);
        } else if (h < wl + 1.7) {
          c = mix(PAL.sandWet, PAL.sand, clamp((h - wl) / 1.7, 0, 1) * 0.7 + mottle * 0.3);
        } else {
          var zoneType = zone ? zone.type : 'meadow';
          if (zoneType === 'forest') {
            var pine = zone && /pine|сосн/i.test((zone.id || '') + ' ' + (zone.name || ''));
            c = pine ? mix(PAL.pine, PAL.pineLight, mottle) : mix(PAL.decid, PAL.decidLight, mottle);
            c = mix(c, pine ? PAL.pineDark : PAL.decidDark, clamp((0.5 - mottle) * 0.7, 0, 1));
          } else if (zoneType === 'farm') {
            var stripe = 0.5 + 0.5 * Math.sin(x * 0.16 + Math.sin(z * 0.045) * 2.2);
            c = mix(PAL.farmDark, PAL.farmLight, mottle * 0.6 + stripe * 0.4);
          } else if (zoneType === 'swamp') {
            c = mix(PAL.swampDark, PAL.swamp, mottle);
            c = mix(c, PAL.swampWet, clamp(this.riverMask[idx] * 0.7 + (h < wl + 1.2 ? 0.35 : 0), 0, 1));
          } else if (zoneType === 'camp') {
            c = mix(PAL.camp, PAL.campLight, mottle);
          } else if (zoneType === 'ruins') {
            c = mix(PAL.ruins, PAL.rockLight, mottle * 0.6);
          } else if (zoneType === 'mountain') {
            c = mix(PAL.mountain, PAL.rockLight, mottle * 0.7);
          } else if (zoneType === 'lake') {
            c = mix(PAL.lakeBed, PAL.seabedShallow, mottle * 0.5);
          } else {
            c = mix(PAL.grass, PAL.grassLight, mottle);
            c = mix(c, PAL.grassDark, clamp((0.45 - mottle) * 0.9, 0, 1));
          }
        }

        if (this.riverMask[idx] > 0.02 && h >= wl - 0.35) {
          c = mix(c, PAL.mud, clamp(this.riverMask[idx] * 0.85, 0, 1));
        }

        var rockAmt = smoothstep(0.42, 0.78, slope);
        rockAmt = Math.max(rockAmt, smoothstep(maxH * 0.58, maxH * 0.86, h) * 0.9);
        if (rockAmt > 0.01) {
          c = mix(c, mix(PAL.rock, PAL.rockLight, mottle), rockAmt);
        }
        if (h > maxH * 0.9) {
          c = mix(c, PAL.snow, smoothstep(maxH * 0.9, maxH, h) * 0.5);
        }

        colors[idx * 3] = srgbToLinear(clamp(c[0], 0, 1));
        colors[idx * 3 + 1] = srgbToLinear(clamp(c[1], 0, 1));
        colors[idx * 3 + 2] = srgbToLinear(clamp(c[2], 0, 1));
      }
    }
    this.colors = colors;
  };

  TerrainBuilder.prototype.zoneVegetation = function (zone, maxCount, seed) {
    if (!zone || !zone.points || zone.points.length < 3) return [];
    var rng = new Noise.Random(seed);
    var bbox = Geo.polygonBBox(zone.points);
    var out = [];
    var tries = maxCount * 12;
    var wl = this.data.terrain.waterLevel;
    for (var t = 0; t < tries && out.length < maxCount; t++) {
      var x = rng.range(bbox.minX, bbox.maxX);
      var z = rng.range(bbox.minZ, bbox.maxZ);
      if (!Geo.pointInPolygon(x, z, zone.points)) continue;
      var info = Geo.polygonInfo(x, z, zone.points);
      if (info.dist < 6) continue;
      var h = this.heightAt(x, z);
      if (h < wl + 0.7) continue;
      var norm = this.normalAt(x, z);
      if (1 - norm.y > 0.5) continue;
      if (this.waterInfoAt(x, z)) continue;
      out.push({ x: x, z: z, h: h, r: rng.next(), r2: rng.next(), r3: rng.next() });
    }
    return out;
  };

  global.CHILL.TerrainBuilder = TerrainBuilder;
  global.CHILL.TERRAIN_RES = RES;
})(window);
