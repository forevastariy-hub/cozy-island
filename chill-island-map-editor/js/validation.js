/* CHILL ISLAND MAP EDITOR - map validation (warnings only, never auto-fixes geography) */
(function (global) {
  'use strict';

  var Geo = global.CHILL.Geo;
  var Data = global.CHILL.Data;

  function issue(severity, code, message, kind, id, x, z) {
    return { severity: severity, code: code, message: message, kind: kind || null, id: id || null, x: x, z: z };
  }

  function validate(data, builder) {
    var issues = [];
    var map = data.map;
    var terrain = data.terrain;
    var wl = terrain.waterLevel;

    /* Unique ids */
    var seen = {};
    function idCheck(list, kind) {
      (list || []).forEach(function (o) {
        if (!o || !o.id) return;
        if (seen[o.id]) {
          issues.push(issue('error', 'duplicate_id', 'Повторяющийся ID «' + o.id + '» (' + kind + ').', kind, o.id));
        }
        seen[o.id] = true;
      });
    }
    idCheck(data.zones, 'zone');
    idCheck(data.rivers, 'river');
    idCheck(data.roads, 'road');
    idCheck(data.landmarks, 'landmark');
    idCheck(data.vegetation, 'vegetation');
    idCheck(terrain.edits, 'terrainEdit');

    /* Coast */
    if (!terrain.coast || !terrain.coast.points || terrain.coast.points.length < 8) {
      issues.push(issue('error', 'coast', 'Береговая линия повреждена: нужно минимум 8 точек.', 'coast', 'coastline'));
    }

    /* Zones */
    (data.zones || []).forEach(function (z) {
      if (!z.points || z.points.length < 3) {
        issues.push(issue('error', 'zone_points', 'Зона «' + z.name + '»: меньше трёх точек полигона.', 'zone', z.id, z.center[0], z.center[1]));
        return;
      }
      if (Geo.polygonArea(z.points) < 1) {
        issues.push(issue('warning', 'zone_area', 'Зона «' + z.name + '» имеет нулевую площадь.', 'zone', z.id, z.center[0], z.center[1]));
      }
      var outside = 0, offMap = 0, outPoint = null;
      z.points.forEach(function (p) {
        var ci = builder.coastInfo(p[0], p[1]);
        if (!ci.inside) {
          outside++;
          if (!outPoint) outPoint = p;
        }
        if (p[0] < 0 || p[1] < 0 || p[0] > map.size.width || p[1] > map.size.length) offMap++;
      });
      if (outside > 0) {
        issues.push(issue('warning', 'zone_outside_coast',
          'Зона «' + z.name + '» выходит за береговую линию (' + outside + ' вершин).',
          'zone', z.id, outPoint ? outPoint[0] : z.center[0], outPoint ? outPoint[1] : z.center[1]));
      }
      if (offMap > 0) {
        issues.push(issue('warning', 'zone_off_map',
          'Зона «' + z.name + '» выходит за границы карты (' + offMap + ' вершин).',
          'zone', z.id, z.center[0], z.center[1]));
      }
      if (z.type !== 'lake' && z.type !== 'swamp') {
        var samples = [z.center].concat(z.points.filter(function (_, i) { return i % 3 === 0; }));
        var wet = samples.some(function (p) { return builder.waterInfoAt(p[0], p[1]); });
        if (wet) {
          issues.push(issue('warning', 'zone_water_overlap',
            'Зона «' + z.name + '» пересекается с водоёмом.',
            'zone', z.id, z.center[0], z.center[1]));
        }
      }
    });

    /* Rivers */
    (data.rivers || []).forEach(function (river) {
      if (!river.points || river.points.length < 2) {
        issues.push(issue('error', 'river_points', 'Река «' + river.name + '»: нужно минимум 2 контрольные точки.', 'river', river.id));
        return;
      }
      if (river.bankWidth < river.depth * 1.6) {
        issues.push(issue('warning', 'river_steep_bank',
          'Река «' + river.name + '»: берег уже, чем нужно для глубины ' + river.depth + '. 3D-превью расширяет переход, чтобы не было отвесных стен.',
          'river', river.id));
      }
      var rd = builder.riverData.find(function (x) { return x.river.id === river.id; });
      if (!rd) return;
      var aboveBank = 0, highHill = 0, uphill = 0, belowSea = 0, outsideCoast = 0;
      var worst = null;
      var maxNatural = -Infinity;
      for (var i = 0; i < rd.pts.length; i++) {
        var p = rd.pts[i];
        var natural = builder.naturalHeightAt(p[0], p[1]);
        var water = rd.waterY[i];
        maxNatural = Math.max(maxNatural, natural);
        if (water < wl - 0.6) belowSea++;
        if (i > 0 && water > rd.waterY[i - 1] + 0.35) uphill++;
        if (natural > map.size.maxHeight * 0.4 || natural - water > 10) highHill++;
        var prev = rd.pts[Math.max(0, i - 1)];
        var next = rd.pts[Math.min(rd.pts.length - 1, i + 1)];
        var dx = next[0] - prev[0], dz = next[1] - prev[1];
        var len = Math.hypot(dx, dz) || 1;
        var nx = -dz / len, nz = dx / len;
        var off = rd.inner + rd.effBank + 3;
        var hL = builder.naturalHeightAt(p[0] + nx * off, p[1] + nz * off);
        var hR = builder.naturalHeightAt(p[0] - nx * off, p[1] - nz * off);
        if (Math.min(hL, hR) < water + 0.03) {
          aboveBank++;
          if (!worst) worst = p;
        }
        var ci = builder.coastInfo(p[0], p[1]);
        if (!ci.inside) outsideCoast++;
      }
      if (aboveBank > 0) {
        issues.push(issue('warning', 'river_above_banks',
          'Река «' + river.name + '»: вода выше берега в ' + aboveBank + ' точках русла.',
          'river', river.id, worst ? worst[0] : null, worst ? worst[1] : null));
      }
      if (highHill > 0) {
        issues.push(issue('warning', 'river_high_hill',
          'Река «' + river.name + '» проходит через высокий холм (макс. высота ' + Math.round(maxNatural) + ').',
          'river', river.id, rd.pts[0][0], rd.pts[0][1]));
      }
      if (uphill > 0) {
        issues.push(issue('warning', 'river_uphill',
          'Река «' + river.name + '» течёт вверх по склону (' + uphill + ' подъёмов). Проверьте направление или высоту воды.',
          'river', river.id, rd.pts[0][0], rd.pts[0][1]));
      }
      if (belowSea > 0) {
        issues.push(issue('warning', 'river_below_sea',
          'Река «' + river.name + '» опускается ниже уровня моря (' + belowSea + ' точек).',
          'river', river.id, rd.pts[0][0], rd.pts[0][1]));
      }
      if (outsideCoast > 0) {
        issues.push(issue('warning', 'river_outside_coast',
          'Река «' + river.name + '» выходит за береговую линию (' + outsideCoast + ' точек).',
          'river', river.id, rd.pts[0][0], rd.pts[0][1]));
      }
    });

    /* Roads */
    (data.roads || []).forEach(function (road) {
      if (!road.points || road.points.length < 2) {
        issues.push(issue('error', 'road_points', 'Дорога «' + road.name + '»: нужно минимум 2 точки.', 'road', road.id));
        return;
      }
      var pts = Geo.catmullRom(road.points, 6);
      var wet = 0, steep = 0, last = null;
      for (var i = 0; i < pts.length; i++) {
        var p = pts[i];
        var h = builder.heightAt(p[0], p[1]);
        if (h < wl + 0.18) { wet++; if (!last) last = p; }
        if (i > 0) {
          var prev = pts[i - 1];
          var h0 = builder.heightAt(prev[0], prev[1]);
          var d = Math.hypot(p[0] - prev[0], p[1] - prev[1]) || 1;
          if (Math.abs(h - h0) / d > 0.95) { steep++; if (!last) last = p; }
        }
      }
      if (wet > 0) {
        issues.push(issue('warning', 'road_underwater',
          'Дорога «' + road.name + '» уходит в воду (' + wet + ' участков).',
          'road', road.id, last ? last[0] : null, last ? last[1] : null));
      }
      if (steep > 0) {
        issues.push(issue('warning', 'road_steep',
          'Дорога «' + road.name + '» имеет обрыв или слишком крутой склон (' + steep + ' участков).',
          'road', road.id, last ? last[0] : null, last ? last[1] : null));
      }
      var e0 = road.points[0];
      var e1 = road.points[road.points.length - 1];
      [[e0, 'начало'], [e1, 'конец']].forEach(function (pair) {
        var p = pair[0];
        var ci = builder.coastInfo(p[0], p[1]);
        if (!ci.inside) {
          issues.push(issue('warning', 'road_end',
            'Дорога «' + road.name + '»: ' + pair[1] + ' дороги за береговой линией.',
            'road', road.id, p[0], p[1]));
        }
      });
      var wetRiver = pts.some(function (p) {
        var wi = builder.waterInfoAt(p[0], p[1]);
        return wi && wi.kind === 'river';
      });
      if (wetRiver && wet === 0) {
        issues.push(issue('info', 'road_river_cross',
          'Дорога «' + road.name + '» пересекает реку. Если нужен мост — отметьте это в генераторе.',
          'road', road.id, road.points[0][0], road.points[0][1]));
      }
    });

    /* Lakes */
    (data.zones || []).forEach(function (z) {
      if (z.type !== 'lake') return;
      var c = Geo.polygonCentroid(z.points);
      var level = z.waterLevel != null ? z.waterLevel : wl + 0.7;
      var minDim = Math.max(10, Math.min(z.size[0], z.size[1]));
      var off = Math.max(8, minDim * 0.16);
      var low = 0, sample = null;
      for (var i = 0; i < z.points.length; i += 2) {
        var p = z.points[i];
        var dx = p[0] - c[0], dz = p[1] - c[1];
        var len = Math.hypot(dx, dz) || 1;
        var sx = p[0] + dx / len * off;
        var sz = p[1] + dz / len * off;
        var h = builder.naturalHeightAt(sx, sz);
        if (h < level + 0.05) { low++; if (!sample) sample = [sx, sz]; }
      }
      if (low > 0) {
        issues.push(issue('warning', 'lake_above_banks',
          'Озеро «' + z.name + '»: вода выше берегов в ' + low + ' проверенных точках.',
          'zone', z.id, sample ? sample[0] : c[0], sample ? sample[1] : c[1]));
      }
    });

    /* Landmarks */
    (data.landmarks || []).forEach(function (lm) {
      var kindInfo = Data.LANDMARK_TYPES[lm.type] || Data.LANDMARK_TYPES.point;
      var wi = builder.waterInfoAt(lm.position[0], lm.position[1]);
      if (wi) {
        var sev = kindInfo.tower ? 'error' : 'warning';
        issues.push(issue(sev, 'landmark_water',
          (kindInfo.tower ? 'Вышка/башня' : 'Объект') + ' «' + lm.name + '» находится в воде (' + wi.kind + ').',
          'landmark', lm.id, lm.position[0], lm.position[1]));
      }
      var h = builder.heightAt(lm.position[0], lm.position[1]);
      if (lm.elevation != null && lm.elevation < h - 0.5) {
        issues.push(issue('warning', 'landmark_underground',
          'Объект «' + lm.name + '» находится под землёй (высота ' + lm.elevation.toFixed(1) + ' < ' + h.toFixed(1) + ').',
          'landmark', lm.id, lm.position[0], lm.position[1]));
      }
      var norm = builder.normalAt(lm.position[0], lm.position[1]);
      if (1 - norm.y > 0.62) {
        issues.push(issue('warning', 'landmark_slope',
          'Объект «' + lm.name + '» стоит на слишком крутом склоне.',
          'landmark', lm.id, lm.position[0], lm.position[1]));
      }
    });

    /* Vegetation */
    (data.vegetation || []).forEach(function (v) {
      var wi = builder.waterInfoAt(v.position[0], v.position[1]);
      if (wi) {
        issues.push(issue('warning', 'veg_water',
          'Растительность «' + v.name + '» в воде (' + wi.kind + ').',
          'vegetation', v.id, v.position[0], v.position[1]));
      }
    });

    /* Terrain edits sanity */
    (terrain.edits || []).forEach(function (e) {
      if (e.radius < 10) {
        issues.push(issue('warning', 'edit_small', 'Рельефная правка «' + e.id + '» слишком мала.', 'terrainEdit', e.id, e.center[0], e.center[1]));
      }
    });

    return issues;
  }

  function summarize(issues) {
    var errors = 0, warnings = 0, info = 0;
    issues.forEach(function (i) {
      if (i.severity === 'error') errors++;
      else if (i.severity === 'warning') warnings++;
      else info++;
    });
    return { errors: errors, warnings: warnings, info: info, total: issues.length };
  }

  global.CHILL.Validator = { validate: validate, summarize: summarize };
})(window);
