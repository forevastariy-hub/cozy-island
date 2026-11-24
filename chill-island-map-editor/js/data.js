/* CHILL ISLAND MAP EDITOR - map schema, defaults and normalization */
(function (global) {
  'use strict';

  var Geo = global.CHILL.Geo;
  var clamp = global.CHILL.Noise.clamp;

  var ZONE_TYPES = {
    forest:   { label: 'Лес',              color: '#3e6b39', priority: 5, water: false },
    lake:     { label: 'Озеро',            color: '#2e6c8e', priority: 9, water: true  },
    swamp:    { label: 'Болото',           color: '#4c5a35', priority: 8, water: true  },
    camp:     { label: 'Лагерь',           color: '#8b7047', priority: 7, water: false },
    farm:     { label: 'Поля',             color: '#958544', priority: 6, water: false },
    meadow:   { label: 'Луг',              color: '#6f8b4b', priority: 4, water: false },
    mountain: { label: 'Горы',             color: '#77726a', priority: 6, water: false },
    ruins:    { label: 'Руины',            color: '#7c7a70', priority: 7, water: false },
    custom:   { label: 'Другая зона',      color: '#707070', priority: 2, water: false }
  };

  var LANDMARK_TYPES = {
    lookout:     { label: 'Смотровая вышка', color: '#b08a55', tower: true  },
    stone_tower: { label: 'Каменная башня',  color: '#9a978c', tower: true  },
    radio_tower: { label: 'Радиовышка',      color: '#8e99a6', tower: true  },
    camp:        { label: 'Лагерь',          color: '#b08a55', tower: false },
    windmill:    { label: 'Мельница',        color: '#a08a66', tower: false },
    farmhouse:   { label: 'Фермерский дом',  color: '#b59a70', tower: false },
    ruins:       { label: 'Руины',           color: '#8a877d', tower: false },
    beacon:      { label: 'Маяк',            color: '#c9b46f', tower: true  },
    point:       { label: 'Точка интереса',  color: '#7fb0c9', tower: false }
  };

  var VEGETATION_TYPES = {
    tree_pine:      { label: 'Сосна',       color: '#2f5a32', kind: 'tree' },
    tree_deciduous: { label: 'Лиственное',  color: '#4d7a35', kind: 'tree' },
    bush:           { label: 'Куст',        color: '#4d7338', kind: 'bush' },
    rock:           { label: 'Камень',      color: '#8a877d', kind: 'rock' },
    flower:         { label: 'Цветы',       color: '#c9a7c9', kind: 'flower' },
    reed:           { label: 'Камыш',       color: '#6e7f45', kind: 'reed' }
  };

  var CROSS_SECTIONS = {
    smooth_u:  { label: 'Плавное U' },
    round_u:   { label: 'Круглое U' },
    flat_bottom: { label: 'Плоское дно' },
    parabolic: { label: 'Парабола' },
    v_shallow: { label: 'Мягкое V' }
  };

  var BANK_TRANSITIONS = {
    smoothstep: { label: 'Smoothstep' },
    linear:     { label: 'Линейный' },
    cubic:      { label: 'Cubic' }
  };

  var FLOW_DIRECTIONS = {
    forward: { label: 'По сплайну (вперёд)' },
    reverse: { label: 'Против сплайна' }
  };

  var SAMPLE_MAP = {
    map: {
      name: 'Cozy Island',
      seed: 12345,
      size: { width: 1000, length: 1000, maxHeight: 90 },
      camera: { type: 'isometric', angle: 45, zoom: 1 }
    },
    terrain: {
      baseHeight: 12,
      hillStrength: 25,
      roughness: 0.3,
      coastBlend: 15
    },
    zones: [
      { id: 'pine_forest', name: 'Сосновый лес', type: 'forest', center: [220, 800], size: [300, 330], density: 0.85 },
      { id: 'lake', name: 'Центральное озеро', type: 'lake', center: [510, 660], size: [200, 130] },
      { id: 'camp', name: 'Лагерь', type: 'camp', center: [500, 420], size: [140, 120] },
      { id: 'swamp', name: 'Болото', type: 'swamp', center: [210, 210], size: [220, 160] },
      { id: 'farmland', name: 'Поля', type: 'farm', center: [780, 600], size: [220, 200] },
      { id: 'deciduous_forest', name: 'Лиственный лес', type: 'forest', center: [650, 230], size: [330, 300], density: 0.85 }
    ],
    rivers: [
      {
        id: 'main_river',
        name: 'Главная река',
        points: [[510, 595], [530, 520], [570, 450], [620, 360], [680, 260], [720, 150]],
        width: 4,
        depth: 0.5,
        bankWidth: 3,
        crossSection: 'smooth_u',
        bankTransition: 'smoothstep'
      }
    ],
    roads: [],
    landmarks: [],
    vegetation: []
  };

  function num(v, def) {
    var n = Number(v);
    return Number.isFinite(n) ? n : def;
  }

  function normPoint(p, fallback) {
    if (Array.isArray(p) && p.length >= 2) {
      var x = Number(p[0]), z = Number(p[1]);
      if (Number.isFinite(x) && Number.isFinite(z)) return [x, z];
    }
    return fallback ? [fallback[0], fallback[1]] : [0, 0];
  }

  function normalizePoints(points, fallbackCenter, fallbackSize) {
    var out = [];
    if (Array.isArray(points)) {
      for (var i = 0; i < points.length; i++) {
        var p = normPoint(points[i], null);
        if (p) out.push(p);
      }
    }
    if (out.length < 3 && fallbackCenter) {
      var rx = Math.max(10, (fallbackSize ? fallbackSize[0] : 120) * 0.5);
      var rz = Math.max(10, (fallbackSize ? fallbackSize[1] : 120) * 0.5);
      out = Geo.ellipsePolygon(fallbackCenter[0], fallbackCenter[1], rx, rz, 24, 0);
    }
    return out;
  }

  function generateCoast(size, seed) {
    var w = size.width, l = size.length;
    var margin = Math.max(6, Math.min(w, l) * 0.014);
    var radius = Math.min(w, l) * 0.12;
    var base = Geo.roundedRectPolygon(margin, margin, w - margin, l - margin, radius, 8);
    var cx = w * 0.5, cz = l * 0.5;
    var phase = (seed % 1000) / 1000 * Math.PI * 2;
    var out = [];
    for (var i = 0; i < base.length; i++) {
      var p = base[i];
      var dx = p[0] - cx, dz = p[1] - cz;
      var len = Math.hypot(dx, dz) || 1;
      var ang = Math.atan2(dz, dx);
      var wob = 5 + 3.2 * Math.sin(ang * 3 + phase) + 2.2 * Math.sin(ang * 7 - phase * 1.7);
      var nx = dx / len, nz = dz / len;
      var x = clamp(p[0] + nx * wob, 4, w - 4);
      var z = clamp(p[1] + nz * wob, 4, l - 4);
      out.push([x, z]);
    }
    return out;
  }

  function collectIds(data) {
    var used = new Set();
    var groups = ['zones', 'rivers', 'roads', 'landmarks', 'vegetation'];
    groups.forEach(function (g) {
      (data[g] || []).forEach(function (o) { if (o && o.id) used.add(String(o.id)); });
    });
    ((data.terrain && data.terrain.edits) || []).forEach(function (e) { if (e && e.id) used.add(String(e.id)); });
    return used;
  }

  function normalize(raw) {
    if (!raw || typeof raw !== 'object') throw new Error('Карта должна быть JSON-объектом');
    var data = Geo.deepClone(raw);
    if (!data.map || typeof data.map !== 'object') data.map = {};
    if (!data.terrain || typeof data.terrain !== 'object') data.terrain = {};

    var map = data.map;
    map.name = String(map.name || 'Cozy Island');
    map.seed = Math.round(num(map.seed, 12345));
    if (!map.size || typeof map.size !== 'object') map.size = {};
    map.size.width = clamp(num(map.size.width, 1000), 200, 8000);
    map.size.length = clamp(num(map.size.length, 1000), 200, 8000);
    map.size.maxHeight = clamp(num(map.size.maxHeight, 90), 10, 500);
    if (!map.camera || typeof map.camera !== 'object') map.camera = {};
    map.camera.type = map.camera.type === 'top' ? 'top' : 'isometric';
    map.camera.angle = clamp(num(map.camera.angle, 45), 0, 90);
    map.camera.zoom = clamp(num(map.camera.zoom, 1), 0.1, 10);

    var terrain = data.terrain;
    terrain.baseHeight = num(terrain.baseHeight, 12);
    terrain.hillStrength = clamp(num(terrain.hillStrength, 25), 0, 200);
    terrain.roughness = clamp(num(terrain.roughness, 0.3), 0, 1);
    terrain.coastBlend = clamp(num(terrain.coastBlend, 15), 2, 200);
    terrain.waterLevel = num(terrain.waterLevel, 0);
    terrain.edits = Array.isArray(terrain.edits) ? terrain.edits : [];

    if (!terrain.coast || typeof terrain.coast !== 'object') terrain.coast = {};
    var coastPts = normalizePoints(terrain.coast.points, null, null);
    if (coastPts.length < 8) {
      coastPts = generateCoast(map.size, map.seed);
    }
    terrain.coast = { points: coastPts };

    function fixId(obj, base, used) {
      var id = obj.id != null ? String(obj.id).trim() : '';
      if (!id) id = base;
      obj.id = Geo.uniqueId(id, used);
    }

    var used = new Set();

    data.zones = Array.isArray(data.zones) ? data.zones : [];
    data.zones = data.zones.filter(function (z) { return z && typeof z === 'object'; });
    data.zones.forEach(function (z, idx) {
      fixId(z, 'zone_' + (idx + 1), used);
      z.name = String(z.name || z.id);
      z.type = ZONE_TYPES[z.type] ? z.type : 'custom';
      if (!Array.isArray(z.center) || z.center.length < 2) {
        if (Array.isArray(z.points) && z.points.length) {
          z.center = Geo.polygonCentroid(normalizePoints(z.points, null, null));
        } else {
          z.center = [map.size.width * 0.5, map.size.length * 0.5];
        }
      }
      z.center = normPoint(z.center, [map.size.width * 0.5, map.size.length * 0.5]);
      if (!Array.isArray(z.size) || z.size.length < 2) {
        if (Array.isArray(z.points) && z.points.length) z.size = Geo.polygonSize(normalizePoints(z.points, null, null));
        else z.size = [120, 120];
      }
      z.size = [Math.max(10, num(z.size[0], 120)), Math.max(10, num(z.size[1], 120))];
      z.density = clamp(num(z.density, z.type === 'forest' ? 0.7 : 0.25), 0, 1);
      z.rotation = num(z.rotation, 0);
      if (!Array.isArray(z.points) || z.points.length < 3) {
        z.points = Geo.ellipsePolygon(z.center[0], z.center[1], z.size[0] * 0.5, z.size[1] * 0.5, 24, z.rotation);
      } else {
        z.points = normalizePoints(z.points, z.center, z.size);
      }
      if (z.type === 'lake' || z.type === 'swamp') {
        z.waterLevel = num(z.waterLevel, terrain.waterLevel + (z.type === 'lake' ? 0.7 : 0.4));
      }
    });

    data.rivers = Array.isArray(data.rivers) ? data.rivers : [];
    data.rivers = data.rivers.filter(function (r) { return r && typeof r === 'object'; });
    data.rivers.forEach(function (r, idx) {
      fixId(r, 'river_' + (idx + 1), used);
      r.name = String(r.name || r.id);
      var pts = [];
      if (Array.isArray(r.points)) {
        r.points.forEach(function (p) {
          if (Array.isArray(p) && p.length >= 2) {
            var x = Number(p[0]), z = Number(p[1]);
            if (Number.isFinite(x) && Number.isFinite(z)) pts.push([x, z]);
          }
        });
      }
      r.points = pts;
      r.width = clamp(num(r.width, 6), 0.5, 120);
      r.depth = clamp(num(r.depth, 0.6), 0.05, 40);
      r.bankWidth = clamp(num(r.bankWidth, 6), 0.2, 200);
      r.waterHeight = num(r.waterHeight, terrain.waterLevel + 1);
      r.autoWater = r.autoWater == null ? true : !!r.autoWater;
      r.smoothness = clamp(num(r.smoothness, 0.5), 0, 1);
      r.crossSection = CROSS_SECTIONS[r.crossSection] ? r.crossSection : 'smooth_u';
      r.bankTransition = BANK_TRANSITIONS[r.bankTransition] ? r.bankTransition : 'smoothstep';
      r.flowDirection = FLOW_DIRECTIONS[r.flowDirection] ? r.flowDirection : 'forward';
    });

    data.roads = Array.isArray(data.roads) ? data.roads : [];
    data.roads = data.roads.filter(function (r) { return r && typeof r === 'object'; });
    data.roads.forEach(function (r, idx) {
      fixId(r, 'road_' + (idx + 1), used);
      r.name = String(r.name || r.id);
      var pts = [];
      if (Array.isArray(r.points)) {
        r.points.forEach(function (p) {
          if (Array.isArray(p) && p.length >= 2) {
            var x = Number(p[0]), z = Number(p[1]);
            if (Number.isFinite(x) && Number.isFinite(z)) pts.push([x, z]);
          }
        });
      }
      r.points = pts;
      r.width = clamp(num(r.width, 6), 0.5, 60);
      r.type = String(r.type || 'dirt');
      r.smoothness = clamp(num(r.smoothness, 0.5), 0, 1);
    });

    data.landmarks = Array.isArray(data.landmarks) ? data.landmarks : [];
    data.landmarks = data.landmarks.filter(function (l) { return l && typeof l === 'object'; });
    data.landmarks.forEach(function (l, idx) {
      fixId(l, 'landmark_' + (idx + 1), used);
      l.name = String(l.name || l.id);
      l.type = LANDMARK_TYPES[l.type] ? l.type : 'point';
      var p = Array.isArray(l.position) ? l.position : l.center;
      l.position = normPoint(p, [map.size.width * 0.5, map.size.length * 0.5]);
      l.rotation = num(l.rotation, 0);
      l.scale = clamp(num(l.scale, 1), 0.1, 10);
      if (l.elevation != null) l.elevation = num(l.elevation, 0);
    });

    data.vegetation = Array.isArray(data.vegetation) ? data.vegetation : [];
    data.vegetation = data.vegetation.filter(function (v) { return v && typeof v === 'object'; });
    data.vegetation.forEach(function (v, idx) {
      fixId(v, 'veg_' + (idx + 1), used);
      v.type = VEGETATION_TYPES[v.type] ? v.type : 'tree_pine';
      v.name = v.name ? String(v.name) : VEGETATION_TYPES[v.type].label;
      var p = Array.isArray(v.position) ? v.position : v.center;
      v.position = normPoint(p, [map.size.width * 0.5, map.size.length * 0.5]);
      v.rotation = num(v.rotation, 0);
      v.scale = clamp(num(v.scale, 1), 0.1, 8);
    });

    terrain.edits = terrain.edits.filter(function (e) { return e && typeof e === 'object'; });
    terrain.edits.forEach(function (e, idx) {
      fixId(e, 'edit_' + (idx + 1), used);
      e.type = ['hill', 'depression', 'plateau', 'cliff'].indexOf(e.type) >= 0 ? e.type : 'hill';
      var p = Array.isArray(e.center) ? e.center : e.position;
      e.center = normPoint(p, [map.size.width * 0.5, map.size.length * 0.5]);
      e.radius = clamp(num(e.radius, 120), 10, 900);
      e.height = clamp(num(e.height, 15), -150, 150);
      e.falloff = clamp(num(e.falloff, 0.55), 0.05, 1);
    });

    return data;
  }

  function defaultData() {
    return normalize(Geo.deepClone(SAMPLE_MAP));
  }

  function exportData(data) {
    var d = normalize(data);
    function rp(p) { return [Geo.round(p[0], 2), Geo.round(p[1], 2)]; }
    function rpts(pts) { return (pts || []).map(rp); }

    var out = {
      map: {
        name: d.map.name,
        seed: d.map.seed,
        size: {
          width: Geo.round(d.map.size.width, 2),
          length: Geo.round(d.map.size.length, 2),
          maxHeight: Geo.round(d.map.size.maxHeight, 2)
        },
        camera: {
          type: d.map.camera.type,
          angle: Geo.round(d.map.camera.angle, 2),
          zoom: Geo.round(d.map.camera.zoom, 3)
        }
      },
      terrain: {
        baseHeight: Geo.round(d.terrain.baseHeight, 3),
        hillStrength: Geo.round(d.terrain.hillStrength, 3),
        roughness: Geo.round(d.terrain.roughness, 3),
        coastBlend: Geo.round(d.terrain.coastBlend, 3),
        waterLevel: Geo.round(d.terrain.waterLevel, 3),
        coast: { points: rpts(d.terrain.coast.points) },
        edits: d.terrain.edits.map(function (e) {
          return {
            id: e.id,
            type: e.type,
            center: rp(e.center),
            radius: Geo.round(e.radius, 2),
            height: Geo.round(e.height, 2),
            falloff: Geo.round(e.falloff, 3)
          };
        })
      },
      zones: d.zones.map(function (z) {
        var o = {
          id: z.id,
          name: z.name,
          type: z.type,
          center: rp(z.center),
          size: [Geo.round(z.size[0], 2), Geo.round(z.size[1], 2)],
          density: Geo.round(z.density, 3),
          rotation: Geo.round(z.rotation || 0, 4),
          points: rpts(z.points)
        };
        if (z.type === 'lake' || z.type === 'swamp') o.waterLevel = Geo.round(z.waterLevel, 3);
        return o;
      }),
      rivers: d.rivers.map(function (r) {
        return {
          id: r.id,
          name: r.name,
          points: rpts(r.points),
          width: Geo.round(r.width, 3),
          depth: Geo.round(r.depth, 3),
          bankWidth: Geo.round(r.bankWidth, 3),
          waterHeight: Geo.round(r.waterHeight, 3),
          autoWater: !!r.autoWater,
          smoothness: Geo.round(r.smoothness, 3),
          crossSection: r.crossSection,
          bankTransition: r.bankTransition,
          flowDirection: r.flowDirection
        };
      }),
      roads: d.roads.map(function (r) {
        return {
          id: r.id,
          name: r.name,
          type: r.type,
          width: Geo.round(r.width, 3),
          smoothness: Geo.round(r.smoothness, 3),
          points: rpts(r.points)
        };
      }),
      landmarks: d.landmarks.map(function (l) {
        var o = {
          id: l.id,
          name: l.name,
          type: l.type,
          position: rp(l.position),
          rotation: Geo.round(l.rotation, 4),
          scale: Geo.round(l.scale, 3)
        };
        if (l.elevation != null) o.elevation = Geo.round(l.elevation, 3);
        return o;
      }),
      vegetation: d.vegetation.map(function (v) {
        return {
          id: v.id,
          type: v.type,
          name: v.name,
          position: rp(v.position),
          rotation: Geo.round(v.rotation, 4),
          scale: Geo.round(v.scale, 3)
        };
      })
    };
    return out;
  }

  function nextId(prefix, data) {
    return Geo.uniqueId(prefix, collectIds(data));
  }

  function priorityOf(type) {
    return (ZONE_TYPES[type] || ZONE_TYPES.custom).priority;
  }

  global.CHILL.Data = {
    ZONE_TYPES: ZONE_TYPES,
    LANDMARK_TYPES: LANDMARK_TYPES,
    VEGETATION_TYPES: VEGETATION_TYPES,
    CROSS_SECTIONS: CROSS_SECTIONS,
    BANK_TRANSITIONS: BANK_TRANSITIONS,
    FLOW_DIRECTIONS: FLOW_DIRECTIONS,
    SAMPLE_MAP: SAMPLE_MAP,
    normalize: normalize,
    defaultData: defaultData,
    exportData: exportData,
    collectIds: collectIds,
    nextId: nextId,
    priorityOf: priorityOf,
    generateCoast: generateCoast
  };
})(window);
