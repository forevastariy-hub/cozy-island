/* CHILL ISLAND MAP EDITOR - Three.js viewport, overlays and camera */
(function (global) {
  'use strict';

  var Geo = global.CHILL.Geo;
  var Data = global.CHILL.Data;
  var clamp = global.CHILL.Noise.clamp;
  var lerp = global.CHILL.Noise.lerp;

  var ZONE_COLORS = {
    forest: '#4f8a4a', lake: '#3d8cab', swamp: '#6d7f4c', camp: '#b08a55',
    farm: '#b8a24e', meadow: '#79a052', mountain: '#948d80', ruins: '#9a968a', custom: '#8a8a8a'
  };
  var EDIT_COLORS = { hill: '#68c47a', depression: '#5a9fd6', plateau: '#d6b95a', cliff: '#d77d5a' };

  function mat(color, opts) {
    var o = { color: color, roughness: 0.92, metalness: 0.0 };
    if (opts) for (var k in opts) o[k] = opts[k];
    return new THREE.MeshStandardMaterial(o);
  }

  function clearGroup(group) {
    while (group.children.length) {
      var child = group.children[0];
      group.remove(child);
      disposeNode(child);
    }
  }

  function disposeNode(node) {
    node.traverse(function (n) {
      if (n.geometry) n.geometry.dispose();
      if (n.material) {
        if (Array.isArray(n.material)) n.material.forEach(disposeMaterial);
        else disposeMaterial(n.material);
      }
    });
  }

  function disposeMaterial(m) {
    if (m.userData && m.userData.shared) return;
    if (m.map) m.map.dispose();
    m.dispose();
  }

  function makeLabelSprite(text, color, fontSize, bg) {
    var canvas = document.createElement('canvas');
    var ctx = canvas.getContext('2d');
    var fs = fontSize || 44;
    ctx.font = '600 ' + fs + 'px system-ui, Segoe UI, sans-serif';
    var w = Math.ceil(ctx.measureText(text).width + fs * 0.9);
    var h = Math.ceil(fs * 1.55);
    canvas.width = Math.max(64, w);
    canvas.height = h;
    ctx = canvas.getContext('2d');
    ctx.font = '600 ' + fs + 'px system-ui, Segoe UI, sans-serif';
    if (bg !== false) {
      ctx.fillStyle = 'rgba(9, 14, 18, 0.76)';
      var r = fs * 0.36;
      ctx.beginPath();
      ctx.moveTo(r, 0); ctx.lineTo(canvas.width - r, 0);
      ctx.quadraticCurveTo(canvas.width, 0, canvas.width, r);
      ctx.lineTo(canvas.width, canvas.height - r);
      ctx.quadraticCurveTo(canvas.width, canvas.height, canvas.width - r, canvas.height);
      ctx.lineTo(r, canvas.height);
      ctx.quadraticCurveTo(0, canvas.height, 0, canvas.height - r);
      ctx.lineTo(0, r);
      ctx.quadraticCurveTo(0, 0, r, 0);
      ctx.fill();
    }
    ctx.fillStyle = color || '#e6edf2';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, fs * 0.45, canvas.height * 0.52);
    var texture = new THREE.CanvasTexture(canvas);
    texture.encoding = THREE.sRGBEncoding;
    var material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false, depthWrite: false });
    var sprite = new THREE.Sprite(material);
    var scale = 0.023;
    sprite.scale.set(canvas.width * scale, canvas.height * scale, 1);
    return sprite;
  }

  function SceneView(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: false });
    this.renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    this.renderer.outputEncoding = THREE.sRGBEncoding;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.06;

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color('#0b1115');
    this.scene.fog = new THREE.Fog('#0b1115', 2200, 5200);

    this.camera = new THREE.PerspectiveCamera(34, 1, 1, 30000);
    this.target = new THREE.Vector3(0, 40, 0);
    this.spherical = { radius: 1500, phi: 0.96, theta: Math.PI * 0.25 };
    this.anim = null;
    this.lastHeightScale = 1;

    this.raycaster = new THREE.Raycaster();
    this.pointerNDC = new THREE.Vector2();

    var hemi = new THREE.HemisphereLight('#b7d3e8', '#343322', 0.95);
    this.scene.add(hemi);
    var sun = new THREE.DirectionalLight('#fff0d2', 1.35);
    sun.position.set(-900, 1600, -700);
    this.scene.add(sun);
    var fill = new THREE.DirectionalLight('#8fb8d8', 0.35);
    fill.position.set(1100, 500, 900);
    this.scene.add(fill);

    this.groups = {};
    var names = ['terrain', 'water', 'zoneFill', 'zoneBorder', 'rivers', 'roads', 'landmarks', 'vegetation', 'edits', 'coast', 'labels', 'handles', 'preview'];
    for (var i = 0; i < names.length; i++) {
      var g = new THREE.Group();
      g.name = names[i];
      this.scene.add(g);
      this.groups[names[i]] = g;
    }

    this.terrainMesh = null;
    this.terrainMaterial = new THREE.MeshStandardMaterial({
      vertexColors: true, roughness: 0.96, metalness: 0.0
    });
    this.terrainMaterial.userData.shared = true;
    this.waterUniforms = [];
    this.grid = null;
    this.initialized = false;
    this.clock = new THREE.Clock();
    this.time = 0;
  }

  SceneView.prototype.setSize = function (w, h) {
    if (w <= 0 || h <= 0) return;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  };

  SceneView.prototype.fitView = function () {
    var data = this.data;
    if (!data) return;
    var size = Math.max(data.map.size.width, data.map.size.length);
    this.target.set(0, (this.data.terrain.baseHeight + 12) * this.heightScale * 0.45, 0);
    this.spherical.radius = size * 1.25;
    this.spherical.theta = Math.PI * 0.25;
    this.spherical.phi = 0.95;
    this.anim = null;
    this.updateCamera();
  };

  SceneView.prototype.updateCamera = function () {
    var s = this.spherical;
    var sinp = Math.sin(s.phi);
    this.camera.position.set(
      this.target.x + s.radius * sinp * Math.sin(s.theta),
      this.target.y + s.radius * Math.cos(s.phi),
      this.target.z + s.radius * sinp * Math.cos(s.theta)
    );
    this.camera.lookAt(this.target);
  };

  SceneView.prototype.orbit = function (dx, dy) {
    this.anim = null;
    this.spherical.theta -= dx * 0.006;
    this.spherical.phi = clamp(this.spherical.phi - dy * 0.006, 0.035, Math.PI * 0.49);
    this.updateCamera();
  };

  SceneView.prototype.pan = function (dx, dy) {
    this.anim = null;
    var scale = this.spherical.radius * 0.0016;
    var right = new THREE.Vector3().setFromMatrixColumn(this.camera.matrix, 0);
    right.y = 0;
    if (right.lengthSq() < 1e-6) right.set(1, 0, 0);
    right.normalize();
    var fwd = new THREE.Vector3();
    this.camera.getWorldDirection(fwd);
    fwd.y = 0;
    if (fwd.lengthSq() < 1e-6) fwd.set(0, 0, -1);
    fwd.normalize();
    this.target.addScaledVector(right, -dx * scale);
    this.target.addScaledVector(fwd, dy * scale);
    this.clampTarget();
    this.updateCamera();
  };

  SceneView.prototype.zoom = function (factor) {
    this.anim = null;
    var data = this.data;
    var size = data ? Math.max(data.map.size.width, data.map.size.length) : 1000;
    this.spherical.radius = clamp(this.spherical.radius * factor, size * 0.12, size * 4.2);
    this.updateCamera();
  };

  SceneView.prototype.clampTarget = function () {
    if (!this.data) return;
    var w = this.data.map.size.width;
    var l = this.data.map.size.length;
    this.target.x = clamp(this.target.x, -w, w);
    this.target.z = clamp(this.target.z, -l, l);
    this.target.y = clamp(this.target.y, -50, this.data.map.size.maxHeight * this.heightScale * 2.2 + 50);
  };

  SceneView.prototype.setViewMode = function (mode, instant) {
    var data = this.data;
    if (!data) return;
    var size = Math.max(data.map.size.width, data.map.size.length);
    var target = new THREE.Vector3(0, (data.terrain.baseHeight + 12) * this.heightScale * 0.45, 0);
    var phi = mode === 'top' ? 0.025 : 0.95;
    var theta = mode === 'top' ? 0 : Math.PI * 0.25;
    var radius = mode === 'top' ? size * 1.45 : size * 1.25;
    if (instant) {
      this.target.copy(target);
      this.spherical.phi = phi;
      this.spherical.theta = theta;
      this.spherical.radius = radius;
      this.anim = null;
      this.updateCamera();
      return;
    }
    this.startCameraAnim(target, { radius: radius, phi: phi, theta: theta });
  };

  SceneView.prototype.focus = function (mapX, mapZ, radiusHint) {
    if (!this.data) return;
    var data = this.data;
    var size = Math.max(data.map.size.width, data.map.size.length);
    var h = this.builder ? this.builder.heightAt(mapX, mapZ) : data.terrain.baseHeight;
    var target = new THREE.Vector3(
      mapX - data.map.size.width * 0.5,
      h * this.heightScale + 40,
      mapZ - data.map.size.length * 0.5
    );
    var r = clamp((radiusHint || 160) * 2.6, size * 0.18, size * 1.8);
    this.startCameraAnim(target, { radius: r, phi: Math.max(this.spherical.phi, 0.65), theta: this.spherical.theta });
  };

  SceneView.prototype.startCameraAnim = function (target, spherical) {
    this.anim = {
      t: 0,
      fromTarget: this.target.clone(),
      toTarget: target.clone(),
      fromSpherical: { radius: this.spherical.radius, phi: this.spherical.phi, theta: this.spherical.theta },
      toSpherical: spherical
    };
  };

  SceneView.prototype.rebuild = function (data, builder, state) {
    this.data = data;
    this.builder = builder;
    var oldScale = this.lastHeightScale || 1;
    this.heightScale = state.view.heightScale;
    var ratio = this.heightScale / oldScale;
    if (this.initialized && Math.abs(ratio - 1) > 1e-6) {
      this.target.y *= ratio;
    }
    this.lastHeightScale = this.heightScale;
    this.state = state;

    var names = Object.keys(this.groups);
    for (var i = 0; i < names.length; i++) clearGroup(this.groups[names[i]]);
    this.waterUniforms = [];
    this.rebuildGrid();

    this.buildTerrain(builder);
    this.buildWater(data, builder);
    this.buildZones(data, builder, state);
    this.buildRivers(data, builder, state);
    this.buildRoads(data, builder, state);
    this.buildLandmarks(data, builder, state);
    this.buildVegetation(data, builder, state);
    this.buildEdits(data, builder, state);
    this.buildCoast(data, builder, state);
    this.buildLabels(data, builder, state);
    this.buildHandles(data, builder, state);

    this.setLayers(state.layers);
    if (!this.initialized) {
      this.initialized = true;
      this.fitView();
    } else {
      this.updateCamera();
    }
  };

  SceneView.prototype.rebuildGrid = function () {
    if (this.grid) {
      this.scene.remove(this.grid);
      this.grid.geometry.dispose();
      this.grid.material.dispose();
      this.grid = null;
    }
    var data = this.data;
    var size = Math.max(data.map.size.width, data.map.size.length);
    var grid = new THREE.GridHelper(size, 10, 0x35505a, 0x24343b);
    grid.position.y = data.terrain.waterLevel * this.heightScale + 0.25;
    grid.material.transparent = true;
    grid.material.opacity = 0.5;
    grid.material.depthWrite = false;
    this.scene.add(grid);
    this.grid = grid;
  };

  SceneView.prototype.buildTerrain = function (builder) {
    var n = builder.n;
    var res = builder.res;
    var positions = new Float32Array(n * n * 3);
    var indices = new Uint32Array(res * res * 6);
    var w = this.data.map.size.width;
    var l = this.data.map.size.length;
    var scale = this.heightScale;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var k = j * n + i;
        positions[k * 3] = i * builder.stepX - w * 0.5;
        positions[k * 3 + 1] = builder.grid[k] * scale;
        positions[k * 3 + 2] = j * builder.stepZ - l * 0.5;
      }
    }
    var p = 0;
    for (var z = 0; z < res; z++) {
      for (var x = 0; x < res; x++) {
        var i0 = z * n + x;
        var i1 = i0 + 1;
        var i2 = i0 + n;
        var i3 = i2 + 1;
        indices[p++] = i0; indices[p++] = i2; indices[p++] = i1;
        indices[p++] = i1; indices[p++] = i2; indices[p++] = i3;
      }
    }
    var geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.BufferAttribute(builder.colors, 3));
    geometry.setIndex(new THREE.BufferAttribute(indices, 1));
    geometry.computeVertexNormals();
    var mesh = new THREE.Mesh(geometry, this.terrainMaterial);
    mesh.name = 'Terrain';
    mesh.receiveShadow = false;
    mesh.userData.pick = { kind: 'terrain', id: 'terrain' };
    this.groups.terrain.add(mesh);
    this.terrainMesh = mesh;
  };

  SceneView.prototype.buildWater = function (data, builder) {
    var g = this.groups.water;
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var wl = data.terrain.waterLevel;

    var oceanGeo = new THREE.PlaneGeometry(w * 4, l * 4, 1, 1);
    var oceanMat = new THREE.MeshStandardMaterial({
      color: '#1e4c5e', roughness: 0.32, metalness: 0.12,
      transparent: true, opacity: 0.9, side: THREE.DoubleSide
    });
    var ocean = new THREE.Mesh(oceanGeo, oceanMat);
    ocean.rotation.x = -Math.PI / 2;
    ocean.position.y = wl * scale;
    ocean.name = 'Ocean';
    g.add(ocean);

    for (var li = 0; li < builder.lakeDefs.length; li++) {
      var def = builder.lakeDefs[li];
      var zone = def.zone;
      var contour = zone.points.map(function (pt) { return new THREE.Vector2(pt[0], pt[1]); });
      var faces;
      try { faces = THREE.ShapeUtils.triangulateShape(contour, []); }
      catch (e) { faces = null; }
      if (!faces || !faces.length) {
        faces = [];
        for (var f = 1; f < contour.length - 1; f++) faces.push([0, f, f + 1]);
      }
      var pos = new Float32Array(contour.length * 3);
      var level = (zone.waterLevel != null ? zone.waterLevel : wl + 0.7) * scale;
      for (var i = 0; i < contour.length; i++) {
        pos[i * 3] = contour[i].x - w * 0.5;
        pos[i * 3 + 1] = level;
        pos[i * 3 + 2] = contour[i].y - l * 0.5;
      }
      var idx = [];
      for (var fi = 0; fi < faces.length; fi++) { idx.push(faces[fi][0], faces[fi][2], faces[fi][1]); }
      var geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      geo.setIndex(idx);
      geo.computeVertexNormals();
      var lakeMat = new THREE.MeshStandardMaterial({
        color: '#2f7c95', roughness: 0.18, metalness: 0.15,
        transparent: true, opacity: 0.8, side: THREE.DoubleSide
      });
      var mesh = new THREE.Mesh(geo, lakeMat);
      mesh.name = 'Lake_' + zone.id;
      mesh.userData.pick = { kind: 'zone', id: zone.id };
      g.add(mesh);
    }
  };

  SceneView.prototype.buildZones = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;

    for (var zi = 0; zi < data.zones.length; zi++) {
      var zone = data.zones[zi];
      var selected = sel && sel.kind === 'zone' && sel.id === zone.id;
      var color = ZONE_COLORS[zone.type] || ZONE_COLORS.custom;
      var bbox = Geo.polygonBBox(zone.points);
      var maxDim = Math.max(bbox.maxX - bbox.minX, bbox.maxZ - bbox.minZ);
      var step = clamp(maxDim / 46, 8, 30);

      var positions = [];
      var indices = [];
      var neighborIndex = {};
      function vert(px, pz) {
        var key = Math.round(px * 10) + ':' + Math.round(pz * 10);
        if (neighborIndex[key] != null) return neighborIndex[key];
        var idx = positions.length / 3;
        var h = builder.heightAt(px, pz);
        positions.push(px - w * 0.5, (h + 0.22) * scale, pz - l * 0.5);
        neighborIndex[key] = idx;
        return idx;
      }

      for (var z0 = bbox.minZ; z0 < bbox.maxZ; z0 += step) {
        for (var x0 = bbox.minX; x0 < bbox.maxX; x0 += step) {
          var cx = x0 + step * 0.5;
          var cz = z0 + step * 0.5;
          if (!Geo.pointInPolygon(cx, cz, zone.points)) continue;
          var x1 = x0 + step, z1 = z0 + step;
          var a = vert(x0, z0);
          var b = vert(x1, z0);
          var c = vert(x0, z1);
          var d = vert(x1, z1);
          indices.push(a, c, b, b, c, d);
        }
      }

      if (positions.length) {
        var geo = new THREE.BufferGeometry();
        geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        geo.setIndex(indices);
        geo.computeVertexNormals();
        var fillMat = new THREE.MeshBasicMaterial({
          color: color, transparent: true,
          opacity: selected ? 0.26 : 0.13,
          depthWrite: false, side: THREE.DoubleSide,
          polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2
        });
        var fill = new THREE.Mesh(geo, fillMat);
        fill.name = 'ZoneFill_' + zone.id;
        fill.userData.pick = { kind: 'zone', id: zone.id };
        this.groups.zoneFill.add(fill);
      }

      var border = this.drapedLoop(zone.points, builder, 6, 0.42);
      var line = new THREE.Line(border.geometry, new THREE.LineBasicMaterial({
        color: selected ? '#ffffff' : color,
        transparent: true,
        opacity: selected ? 1 : 0.82
      }));
      line.userData.pick = { kind: 'zone', id: zone.id };
      this.groups.zoneBorder.add(line);
    }
  };

  SceneView.prototype.drapedLoop = function (points, builder, step, offset) {
    var scale = this.heightScale;
    var w = this.data.map.size.width;
    var l = this.data.map.size.length;
    var samples = Geo.perimeterSamples(points, step, true);
    var pos = [];
    for (var i = 0; i < samples.length; i++) {
      var p = samples[i];
      var h = builder.heightAt(p[0], p[1]);
      pos.push(p[0] - w * 0.5, (h + offset) * scale, p[1] - l * 0.5);
    }
    if (samples.length) {
      var f = samples[0];
      var hf = builder.heightAt(f[0], f[1]);
      pos.push(f[0] - w * 0.5, (hf + offset) * scale, f[1] - l * 0.5);
    }
    var geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    return { geometry: geo, samples: samples };
  };

  SceneView.prototype.buildRivers = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;
    var g = this.groups.rivers;

    for (var ri = 0; ri < builder.riverData.length; ri++) {
      var rd = builder.riverData[ri];
      var selected = sel && sel.kind === 'river' && sel.id === rd.river.id;
      var pts = rd.pts;
      var pos = [];
      var uv = [];
      var idx = [];
      for (var i = 0; i < pts.length; i++) {
        var prev = pts[Math.max(0, i - 1)];
        var next = pts[Math.min(pts.length - 1, i + 1)];
        var dx = next[0] - prev[0];
        var dz = next[1] - prev[1];
        var len = Math.hypot(dx, dz) || 1;
        var nx = -dz / len;
        var nz = dx / len;
        var half = Math.max(0.55, rd.river.width * 0.5 * 0.94);
        var y = rd.waterY[i] * scale + 0.075;
        pos.push(pts[i][0] + nx * half - w * 0.5, y, pts[i][1] + nz * half - l * 0.5);
        pos.push(pts[i][0] - nx * half - w * 0.5, y, pts[i][1] - nz * half - l * 0.5);
        var v = rd.accum[i] / 20;
        uv.push(0, v, 1, v);
        if (i < pts.length - 1) {
          var a = i * 2, b = a + 1, c = a + 2, d = a + 3;
          idx.push(a, c, b, b, c, d);
        }
      }
      var geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
      geo.setIndex(idx);
      geo.computeVertexNormals();
      var uniforms = {
        uTime: { value: 0 },
        uFlow: { value: rd.river.flowDirection === 'reverse' ? -1 : 1 },
        uColor: { value: new THREE.Color(selected ? '#63c9de' : '#3f9fb8') },
        uOpacity: { value: selected ? 0.9 : 0.82 }
      };
      var material = new THREE.ShaderMaterial({
        uniforms: uniforms,
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        vertexShader: [
          'varying vec2 vUv;',
          'void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }'
        ].join('\n'),
        fragmentShader: [
          'varying vec2 vUv;',
          'uniform float uTime;',
          'uniform float uFlow;',
          'uniform vec3 uColor;',
          'uniform float uOpacity;',
          'void main(){',
          '  float ripple = sin(vUv.y * 6.0 - uTime * 1.7 * uFlow);',
          '  float edge = smoothstep(0.0, 0.16, vUv.x) * smoothstep(1.0, 0.84, vUv.x);',
          '  vec3 col = uColor + ripple * 0.035;',
          '  gl_FragColor = vec4(col, uOpacity * edge);',
          '}'
        ].join('\n')
      });
      this.waterUniforms.push(uniforms);
      var mesh = new THREE.Mesh(geo, material);
      mesh.name = 'River_' + rd.river.id;
      mesh.userData.pick = { kind: 'river', id: rd.river.id };
      g.add(mesh);
    }
  };

  SceneView.prototype.buildRoads = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;
    for (var ri = 0; ri < data.roads.length; ri++) {
      var road = data.roads[ri];
      if (!road.points || road.points.length < 2) continue;
      var selected = sel && sel.kind === 'road' && sel.id === road.id;
      var pts = Geo.catmullRom(road.points, 4);
      var pos = [];
      var idx = [];
      for (var i = 0; i < pts.length; i++) {
        var prev = pts[Math.max(0, i - 1)];
        var next = pts[Math.min(pts.length - 1, i + 1)];
        var dx = next[0] - prev[0], dz = next[1] - prev[1];
        var len = Math.hypot(dx, dz) || 1;
        var nx = -dz / len, nz = dx / len;
        var half = Math.max(0.6, road.width * 0.5);
        var lx = pts[i][0] + nx * half, lz = pts[i][1] + nz * half;
        var rx = pts[i][0] - nx * half, rz = pts[i][1] - nz * half;
        pos.push(lx - w * 0.5, (builder.heightAt(lx, lz) + 0.28) * scale, lz - l * 0.5);
        pos.push(rx - w * 0.5, (builder.heightAt(rx, rz) + 0.28) * scale, rz - l * 0.5);
        if (i < pts.length - 1) {
          var a = i * 2, b = a + 1, c = a + 2, d = a + 3;
          idx.push(a, c, b, b, c, d);
        }
      }
      var geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      geo.setIndex(idx);
      geo.computeVertexNormals();
      var mesh = new THREE.Mesh(geo, mat(selected ? '#e4cf9b' : '#b59b6d', { roughness: 1, side: THREE.DoubleSide }));
      mesh.name = 'Road_' + road.id;
      mesh.userData.pick = { kind: 'road', id: road.id };
      this.groups.roads.add(mesh);
    }
  };

  SceneView.prototype.buildLandmarkVisual = function (type) {
    var g = new THREE.Group();
    var wood = mat('#6b4a2b');
    var stone = mat('#8d897d');
    var darkStone = mat('#726e63');
    var cloth = mat('#d8c49a');
    var metal = mat('#97a4ad', { metalness: 0.35, roughness: 0.5 });
    var roofMat = mat('#8a4f37');

    function box(geo, material, x, y, z, ry) {
      var m = new THREE.Mesh(geo, material);
      m.position.set(x, y, z);
      if (ry) m.rotation.y = ry;
      g.add(m);
      return m;
    }
    function cyl(rTop, rBot, h, seg, material, x, y, z) {
      var mesh = new THREE.Mesh(new THREE.CylinderGeometry(rTop, rBot, h, seg), material);
      mesh.position.set(x, y, z);
      g.add(mesh);
      return mesh;
    }

    if (type === 'lookout') {
      cyl(1.1, 1.7, 14, 8, stone, 0, 7, 0);
      box(new THREE.BoxGeometry(6.4, 0.5, 6.4), wood, 0, 14.3, 0);
      cyl(0.1, 3.1, 2.4, 8, wood, 0, 15.8, 0);
      for (var i = 0; i < 4; i++) {
        var a = i * Math.PI / 2;
        box(new THREE.BoxGeometry(0.22, 2.4, 0.22), wood, Math.cos(a) * 2.7, 15.6, Math.sin(a) * 2.7);
      }
    } else if (type === 'stone_tower') {
      cyl(1.6, 2.1, 10, 9, stone, 0, 5, 0);
      for (var s = 0; s < 6; s++) {
        var aa = s * Math.PI / 3;
        box(new THREE.BoxGeometry(0.9, 1.1, 0.9), darkStone, Math.cos(aa) * 1.7, 10.4, Math.sin(aa) * 1.7);
      }
    } else if (type === 'radio_tower') {
      for (var c = 0; c < 4; c++) {
        var ang = c * Math.PI / 2;
        var leg = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.32, 20, 5), metal);
        leg.position.set(Math.cos(ang) * 2.2, 10, Math.sin(ang) * 2.2);
        leg.rotation.z = Math.cos(ang) * 0.12;
        g.add(leg);
      }
      cyl(0.22, 0.42, 23, 6, metal, 0, 11.5, 0);
      box(new THREE.BoxGeometry(5.4, 0.3, 5.4), wood, 0, 9, 0);
      box(new THREE.BoxGeometry(4.4, 0.3, 4.4), wood, 0, 15, 0);
      var dish = new THREE.Mesh(new THREE.SphereGeometry(2.2, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2), metal);
      dish.position.set(0, 23.4, 0);
      dish.rotation.x = Math.PI;
      dish.scale.set(1, 0.45, 1);
      g.add(dish);
    } else if (type === 'camp') {
      cyl(0.01, 2.4, 3.2, 6, cloth, 0, 1.6, 0);
      var fire = new THREE.Mesh(new THREE.ConeGeometry(0.8, 1.2, 6), mat('#e0a24e', { emissive: '#5b2b12', emissiveIntensity: 0.6 }));
      fire.position.y = 0.6;
      g.add(fire);
      for (var k = 0; k < 6; k++) {
        var ka = k * Math.PI / 3;
        box(new THREE.BoxGeometry(0.6, 0.35, 0.6), darkStone, Math.cos(ka) * 1.3, 0.2, Math.sin(ka) * 1.3);
      }
    } else if (type === 'windmill') {
      cyl(2.5, 3.3, 10, 9, stone, 0, 5, 0);
      cyl(0.1, 3.4, 3.2, 9, roofMat, 0, 11.6, 0);
      var hub = new THREE.Group();
      hub.position.set(0, 9, 3.4);
      for (var b = 0; b < 4; b++) {
        var ba = b * Math.PI / 2;
        var blade = box(new THREE.BoxGeometry(0.35, 7.4, 0.16), cloth, 0, 0, 0);
        blade.position.set(Math.cos(ba) * 3.4, Math.sin(ba) * 3.4, 0);
        blade.rotation.z = ba;
        g.add(blade);
      }
      g.add(hub);
    } else if (type === 'farmhouse') {
      box(new THREE.BoxGeometry(9, 4.4, 6.6), mat('#c2ad86'), 0, 2.2, 0);
      var roofL = box(new THREE.BoxGeometry(6.5, 0.4, 7.6), roofMat, -2.15, 5, 0);
      roofL.rotation.z = 0.55;
      var roofR = box(new THREE.BoxGeometry(6.5, 0.4, 7.6), roofMat, 2.15, 5, 0);
      roofR.rotation.z = -0.55;
      box(new THREE.BoxGeometry(1.5, 2.6, 0.2), wood, 0, 1.3, 3.35);
    } else if (type === 'ruins') {
      for (var r = 0; r < 5; r++) {
        var ra = r * Math.PI * 0.42;
        var rr = 2.2 + (r % 2) * 2.2;
        cyl(0.6, 0.8, 3 + (r % 3) * 2.2, 7, stone, Math.cos(ra) * rr, 1.6, Math.sin(ra) * rr);
      }
      box(new THREE.BoxGeometry(7, 0.5, 7), darkStone, 0, 0.25, 0);
    } else if (type === 'beacon') {
      cyl(1.3, 2.1, 11, 8, mat('#d8d4c8'), 0, 5.5, 0);
      cyl(0.1, 2.6, 2.8, 8, roofMat, 0, 12.4, 0);
      var lamp = new THREE.Mesh(new THREE.SphereGeometry(0.7, 8, 6), mat('#ffe4a0', { emissive: '#ffca55', emissiveIntensity: 0.8 }));
      lamp.position.y = 13.4;
      g.add(lamp);
    } else {
      cyl(0.35, 0.5, 0.5, 6, stone, 0, 0.25, 0);
      var flag = new THREE.Mesh(new THREE.SphereGeometry(1.5, 10, 8), mat('#7fb0c9', { emissive: '#1d3947', emissiveIntensity: 0.4 }));
      flag.position.y = 3;
      g.add(flag);
      cyl(0.18, 0.18, 3, 5, wood, 0, 1.5, 0);
    }
    return g;
  };

  SceneView.prototype.buildLandmarks = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;
    for (var i = 0; i < data.landmarks.length; i++) {
      var lm = data.landmarks[i];
      var h = builder.heightAt(lm.position[0], lm.position[1]);
      var g = this.buildLandmarkVisual(lm.type);
      g.position.set(lm.position[0] - w * 0.5, h * scale, lm.position[1] - l * 0.5);
      g.rotation.y = lm.rotation || 0;
      g.scale.setScalar(lm.scale || 1);
      g.name = 'Landmark_' + lm.id;
      g.traverse(function (n) { if (n.isMesh) n.userData.pick = { kind: 'landmark', id: lm.id }; });
      var selected = sel && sel.kind === 'landmark' && sel.id === lm.id;
      if (selected) {
        var ring = new THREE.Mesh(new THREE.TorusGeometry(9 * (lm.scale || 1), 0.7, 6, 28), new THREE.MeshBasicMaterial({ color: '#ffffff' }));
        ring.rotation.x = -Math.PI / 2;
        ring.position.y = 0.4;
        g.add(ring);
      }
      this.groups.landmarks.add(g);
    }
  };

  SceneView.prototype.buildVegetation = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;
    var g = this.groups.vegetation;

    for (var i = 0; i < data.vegetation.length; i++) {
      var v = data.vegetation[i];
      var h = builder.heightAt(v.position[0], v.position[1]);
      var obj = this.buildVegetationVisual(v.type, v.scale || 1);
      obj.position.set(v.position[0] - w * 0.5, h * scale, v.position[1] - l * 0.5);
      obj.rotation.y = v.rotation || 0;
      obj.name = 'Veg_' + v.id;
      obj.traverse(function (n) { if (n.isMesh) n.userData.pick = { kind: 'vegetation', id: v.id }; });
      var selected = sel && sel.kind === 'vegetation' && sel.id === v.id;
      if (selected) {
        var ring = new THREE.Mesh(new THREE.TorusGeometry(5.5 * (v.scale || 1), 0.5, 6, 24), new THREE.MeshBasicMaterial({ color: '#ffffff' }));
        ring.rotation.x = -Math.PI / 2;
        ring.position.y = 0.25;
        obj.add(ring);
      }
      g.add(obj);
    }

    for (var zi = 0; zi < data.zones.length; zi++) {
      var zone = data.zones[zi];
      if (zone.type !== 'forest' && zone.type !== 'swamp' && zone.type !== 'meadow') continue;
      var area = Geo.polygonArea(zone.points);
      var maxCount;
      if (zone.type === 'forest') maxCount = clamp(Math.round(zone.density * area / 170), 10, 520);
      else if (zone.type === 'swamp') maxCount = clamp(Math.round(zone.density * area / 1350), 4, 140);
      else maxCount = clamp(Math.round(zone.density * area / 3200), 2, 60);
      if (maxCount <= 0) continue;
      var points = builder.zoneVegetation(zone, maxCount, (data.map.seed || 1) + zi * 997 + 31);
      if (!points.length) continue;
      var pine = /pine|сосн/i.test((zone.id || '') + ' ' + (zone.name || ''));
      var useReed = zone.type === 'swamp';
      var kind = useReed ? 'reed' : (zone.type === 'meadow' ? 'bush' : (pine ? 'pine' : 'decid'));
      this.addInstancedVegetation(kind, points, w, l, scale, pine);
    }
  };

  SceneView.prototype.buildVegetationVisual = function (type, scale) {
    var g = new THREE.Group();
    var s = scale || 1;
    if (type === 'tree_pine') {
      var trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.55, 4, 6), mat('#5e4228'));
      trunk.position.y = 2;
      g.add(trunk);
      var c1 = new THREE.Mesh(new THREE.ConeGeometry(3.2, 6.2, 7), mat('#2f5a32'));
      c1.position.y = 6;
      g.add(c1);
      var c2 = new THREE.Mesh(new THREE.ConeGeometry(2.4, 5, 7), mat('#376638'));
      c2.position.y = 9.4;
      g.add(c2);
    } else if (type === 'tree_deciduous') {
      var tr = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.65, 5, 6), mat('#6a4b2c'));
      tr.position.y = 2.5;
      g.add(tr);
      var crown = new THREE.Mesh(new THREE.IcosahedronGeometry(4.2, 1), mat('#4d7a35'));
      crown.position.y = 7.2;
      crown.scale.set(1.1, 0.95, 1.1);
      g.add(crown);
      var crown2 = new THREE.Mesh(new THREE.IcosahedronGeometry(2.4, 1), mat('#5c8a3e'));
      crown2.position.set(2.6, 6.2, 1.2);
      g.add(crown2);
    } else if (type === 'bush') {
      var b = new THREE.Mesh(new THREE.IcosahedronGeometry(2.2, 1), mat('#4d7338'));
      b.position.y = 1.8;
      b.scale.y = 0.8;
      g.add(b);
    } else if (type === 'rock') {
      var r = new THREE.Mesh(new THREE.DodecahedronGeometry(2.2, 0), mat('#8a877d'));
      r.position.y = 1.4;
      r.scale.set(1.2, 0.9, 1);
      g.add(r);
    } else if (type === 'flower') {
      var stem = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 1.6, 4), mat('#5d7d3c'));
      stem.position.y = 0.8;
      g.add(stem);
      var head = new THREE.Mesh(new THREE.IcosahedronGeometry(0.55, 0), mat('#d4a7cc'));
      head.position.y = 1.8;
      g.add(head);
    } else {
      for (var i = 0; i < 5; i++) {
        var reed = new THREE.Mesh(new THREE.ConeGeometry(0.18, 3.2 + (i % 3) * 0.7, 4), mat('#6e7f45'));
        reed.position.set(Math.cos(i * 1.3) * 0.8, 1.6, Math.sin(i * 1.3) * 0.8);
        reed.rotation.z = (i % 2 ? 1 : -1) * 0.12;
        g.add(reed);
      }
    }
    g.scale.setScalar(s);
    return g;
  };

  SceneView.prototype.addInstancedVegetation = function (kind, points, mapW, mapL, heightScale, pine) {
    var count = points.length;
    var geom, material, baseY, sizeMul;
    if (kind === 'pine') {
      geom = new THREE.ConeGeometry(2.9, 13, 7);
      geom.translate(0, 6.5, 0);
      material = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.95 });
      sizeMul = 1;
    } else if (kind === 'decid') {
      geom = new THREE.IcosahedronGeometry(3.8, 0);
      geom.translate(0, 3.8, 0);
      material = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.95 });
      sizeMul = 1;
    } else if (kind === 'reed') {
      geom = new THREE.ConeGeometry(0.45, 4.2, 4);
      geom.translate(0, 2.1, 0);
      material = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 1 });
      sizeMul = 1;
    } else {
      geom = new THREE.IcosahedronGeometry(1.8, 0);
      geom.translate(0, 1.8, 0);
      material = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 1 });
      sizeMul = 1;
    }
    var mesh = new THREE.InstancedMesh(geom, material, count);
    mesh.instanceMatrix.setUsage(THREE.StaticDrawUsage);
    var mtx = new THREE.Matrix4();
    var q = new THREE.Quaternion();
    var pos = new THREE.Vector3();
    var scl = new THREE.Vector3();
    var color = new THREE.Color();
    for (var i = 0; i < count; i++) {
      var p = points[i];
      var s = (kind === 'reed' ? 0.7 : 0.7) + p.r * 0.85;
      if (kind === 'decid') s *= 1.15;
      pos.set(p.x - mapW * 0.5, p.h * heightScale, p.z - mapL * 0.5);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), p.r3 * Math.PI * 2);
      scl.set(s * sizeMul, s * (0.9 + p.r2 * 0.35), s * sizeMul);
      mtx.compose(pos, q, scl);
      mesh.setMatrixAt(i, mtx);
      if (kind === 'pine') color.set(p.r > 0.5 ? '#2f5a32' : '#376638');
      else if (kind === 'decid') color.set(p.r > 0.5 ? '#4d7a35' : '#5b883e');
      else if (kind === 'reed') color.set(p.r > 0.5 ? '#6e7f45' : '#7e8d50');
      else color.set(p.r > 0.5 ? '#557d3d' : '#668a44');
      mesh.setColorAt(i, color);
    }
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    mesh.frustumCulled = false;
    this.groups.vegetation.add(mesh);
  };

  SceneView.prototype.buildEdits = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var sel = state.selection;
    var edits = data.terrain.edits || [];
    for (var i = 0; i < edits.length; i++) {
      var e = edits[i];
      var selected = sel && sel.kind === 'terrainEdit' && sel.id === e.id;
      var color = EDIT_COLORS[e.type] || '#aaaaaa';
      var circle = [];
      for (var a = 0; a <= 48; a++) {
        var ang = a / 48 * Math.PI * 2;
        circle.push([e.center[0] + Math.cos(ang) * e.radius, e.center[1] + Math.sin(ang) * e.radius]);
      }
      var line = this.drapedLoop(circle, builder, 1e9, 0.7);
      var marker = new THREE.Line(line.geometry, new THREE.LineBasicMaterial({
        color: selected ? '#ffffff' : color, transparent: true, opacity: 0.9
      }));
      marker.userData.pick = { kind: 'terrainEdit', id: e.id };
      this.groups.edits.add(marker);

      var h = builder.heightAt(e.center[0], e.center[1]);
      var dot = new THREE.Mesh(new THREE.SphereGeometry(selected ? 5 : 3.5, 10, 8),
        new THREE.MeshBasicMaterial({ color: selected ? '#ffffff' : color }));
      dot.position.set(e.center[0] - w * 0.5, (h + 2) * scale, e.center[1] - l * 0.5);
      dot.userData.pick = { kind: 'terrainEdit', id: e.id };
      this.groups.edits.add(dot);
    }
  };

  SceneView.prototype.buildCoast = function (data, builder, state) {
    var selected = state.selection && state.selection.kind === 'coast';
    var line = this.drapedLoop(data.terrain.coast.points, builder, 8, 0.5);
    var obj = new THREE.Line(line.geometry, new THREE.LineBasicMaterial({
      color: selected ? '#ffffff' : '#d9c79a', transparent: true, opacity: 0.85
    }));
    obj.userData.pick = { kind: 'coast', id: 'coastline' };
    this.groups.coast.add(obj);
  };

  SceneView.prototype.buildLabels = function (data, builder, state) {
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    for (var i = 0; i < data.zones.length; i++) {
      var z = data.zones[i];
      var c = Geo.polygonCentroid(z.points);
      var h = builder.heightAt(c[0], c[1]);
      var sprite = makeLabelSprite(z.name, '#e8f0f5', 40);
      sprite.position.set(c[0] - w * 0.5, (h + 20) * scale, c[1] - l * 0.5);
      this.groups.labels.add(sprite);
    }
    for (var li = 0; li < data.landmarks.length; li++) {
      var lm = data.landmarks[li];
      var hh = builder.heightAt(lm.position[0], lm.position[1]);
      var sp = makeLabelSprite(lm.name, '#c9d8e0', 34);
      sp.scale.multiplyScalar(0.72);
      sp.position.set(lm.position[0] - w * 0.5, (hh + 26) * scale, lm.position[1] - l * 0.5);
      this.groups.labels.add(sp);
    }
  };

  SceneView.prototype.buildHandles = function (data, builder, state) {
    var sel = state.selection;
    if (!sel) return;
    var g = this.groups.handles;
    var w = data.map.size.width;
    var l = data.map.size.length;
    var scale = this.heightScale;
    var size = Math.max(w, l);
    var radius = clamp(size * 0.006, 2.5, 9);

    function addHandle(mapX, mapZ, color, part, index, yExtra) {
      var h = builder.heightAt(mapX, mapZ);
      var mesh = new THREE.Mesh(
        new THREE.SphereGeometry(part === 'center' || part === 'position' ? radius * 1.3 : radius, 12, 9),
        new THREE.MeshBasicMaterial({ color: color, depthTest: false })
      );
      mesh.position.set(mapX - w * 0.5, (h + (yExtra || 1.2)) * scale, mapZ - l * 0.5);
      mesh.renderOrder = 20;
      mesh.userData.handle = { kind: sel.kind, id: sel.id, part: part, index: index == null ? -1 : index };
      g.add(mesh);
    }

    if (sel.kind === 'zone') {
      var z = data.zones.find(function (zz) { return zz.id === sel.id; });
      if (!z) return;
      var c = Geo.polygonCentroid(z.points);
      addHandle(c[0], c[1], '#ffffff', 'center', -1, 4);
      for (var i = 0; i < z.points.length; i++) {
        addHandle(z.points[i][0], z.points[i][1], '#58c7ff', 'point', i, 1.2);
      }
    } else if (sel.kind === 'river') {
      var r = data.rivers.find(function (rr) { return rr.id === sel.id; });
      if (!r) return;
      for (var ri = 0; ri < r.points.length; ri++) {
        addHandle(r.points[ri][0], r.points[ri][1], '#54d6a0', 'point', ri, 1.2);
      }
    } else if (sel.kind === 'road') {
      var rd = data.roads.find(function (rr) { return rr.id === sel.id; });
      if (!rd) return;
      for (var di = 0; di < rd.points.length; di++) {
        addHandle(rd.points[di][0], rd.points[di][1], '#e8c15a', 'point', di, 1.2);
      }
    } else if (sel.kind === 'coast') {
      for (var ci = 0; ci < data.terrain.coast.points.length; ci++) {
        addHandle(data.terrain.coast.points[ci][0], data.terrain.coast.points[ci][1], '#e0d6b8', 'point', ci, 1.2);
      }
    } else if (sel.kind === 'terrainEdit') {
      var e = (data.terrain.edits || []).find(function (ee) { return ee.id === sel.id; });
      if (!e) return;
      addHandle(e.center[0], e.center[1], '#ffffff', 'center', -1, 3);
    } else if (sel.kind === 'landmark') {
      var lm = data.landmarks.find(function (x) { return x.id === sel.id; });
      if (!lm) return;
      addHandle(lm.position[0], lm.position[1], '#ffffff', 'position', -1, 14);
    } else if (sel.kind === 'vegetation') {
      var v = data.vegetation.find(function (x) { return x.id === sel.id; });
      if (!v) return;
      addHandle(v.position[0], v.position[1], '#ffffff', 'position', -1, 4);
    }
  };

  SceneView.prototype.setLayers = function (layers) {
    this.groups.water.visible = !!layers.water;
    this.groups.zoneFill.visible = !!layers.zoneFill;
    this.groups.zoneBorder.visible = !!layers.zoneBorders;
    this.groups.rivers.visible = !!layers.rivers;
    this.groups.roads.visible = !!layers.roads;
    this.groups.landmarks.visible = !!layers.landmarks;
    this.groups.vegetation.visible = !!layers.vegetation;
    this.groups.edits.visible = !!layers.terrainEdits;
    this.groups.coast.visible = !!layers.coastline;
    this.groups.labels.visible = !!layers.labels;
    this.groups.handles.visible = !!layers.handles;
    this.groups.preview.visible = true;
    if (this.grid) this.grid.visible = !!layers.grid;
  };

  SceneView.prototype.raycastTerrain = function (clientX, clientY) {
    if (!this.terrainMesh) return null;
    var rect = this.canvas.getBoundingClientRect();
    this.pointerNDC.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    this.pointerNDC.y = -((clientY - rect.top) / rect.height) * 2 + 1;
    this.raycaster.setFromCamera(this.pointerNDC, this.camera);
    var hits = this.raycaster.intersectObject(this.terrainMesh, false);
    if (!hits.length) return null;
    var p = hits[0].point;
    var data = this.data;
    return {
      x: p.x + data.map.size.width * 0.5,
      z: p.z + data.map.size.length * 0.5,
      height: p.y / this.heightScale,
      point: p
    };
  };

  SceneView.prototype.pickAt = function (clientX, clientY) {
    if (!this.data) return null;
    var rect = this.canvas.getBoundingClientRect();
    this.pointerNDC.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    this.pointerNDC.y = -((clientY - rect.top) / rect.height) * 2 + 1;
    this.raycaster.setFromCamera(this.pointerNDC, this.camera);
    var targets = [
      this.groups.handles, this.groups.landmarks, this.groups.vegetation,
      this.groups.rivers, this.groups.roads, this.groups.edits,
      this.groups.zoneBorder, this.groups.zoneFill, this.groups.coast
    ];
    var hits = this.raycaster.intersectObjects(targets, true);
    var firstPick = null;
    for (var i = 0; i < hits.length; i++) {
      var obj = hits[i].object;
      var node = obj;
      while (node) {
        if (node.userData && node.userData.handle) {
          return { type: 'handle', handle: node.userData.handle, object: node, point: hits[i].point, distance: hits[i].distance };
        }
        node = node.parent;
      }
    }
    for (var h = 0; h < hits.length; h++) {
      var o = hits[h].object;
      var nd = o;
      while (nd) {
        if (nd.userData && nd.userData.pick && nd.userData.pick.kind !== 'terrain') {
          firstPick = { type: 'pick', pick: nd.userData.pick, object: o, point: hits[h].point, distance: hits[h].distance };
          break;
        }
        nd = nd.parent;
      }
      if (firstPick) break;
    }
    if (firstPick) return firstPick;
    var t = this.raycastTerrain(clientX, clientY);
    if (t) return { type: 'terrain', x: t.x, z: t.z, height: t.height, point: t.point };
    return null;
  };

  SceneView.prototype.showDrawPreview = function (points, cursor, kind) {
    var g = this.groups.preview;
    clearGroup(g);
    if (!this.builder || (!points || !points.length) && !cursor) return;
    var w = this.data.map.size.width;
    var l = this.data.map.size.length;
    var scale = this.heightScale;
    var color = kind === 'river' ? '#54d6a0' : (kind === 'road' ? '#e8c15a' : '#7fd1ff');
    var all = (points || []).slice();
    if (cursor) all.push([cursor.x, cursor.z]);
    if (all.length >= 2) {
      var pos = [];
      for (var i = 0; i < all.length; i++) {
        var h = this.builder.heightAt(all[i][0], all[i][1]);
        pos.push(all[i][0] - w * 0.5, (h + 1.4) * scale, all[i][1] - l * 0.5);
      }
      var geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      var dash = new THREE.Line(geo, new THREE.LineDashedMaterial({ color: color, dashSize: 8, gapSize: 5, transparent: true, opacity: 0.95 }));
      dash.computeLineDistances();
      g.add(dash);
    }
    var dotGeo = new THREE.SphereGeometry(3.5, 8, 6);
    var dotMat = new THREE.MeshBasicMaterial({ color: color });
    for (var p = 0; p < (points || []).length; p++) {
      var hh = this.builder.heightAt(points[p][0], points[p][1]);
      var dot = new THREE.Mesh(dotGeo, dotMat);
      dot.position.set(points[p][0] - w * 0.5, (hh + 1.5) * scale, points[p][1] - l * 0.5);
      g.add(dot);
    }
  };

  SceneView.prototype.showBrushPreview = function (x, z, radius, color) {
    var g = this.groups.preview;
    clearGroup(g);
    if (!this.builder || x == null) return;
    var w = this.data.map.size.width;
    var l = this.data.map.size.length;
    var scale = this.heightScale;
    var pts = [];
    for (var a = 0; a <= 48; a++) {
      var ang = a / 48 * Math.PI * 2;
      pts.push([x + Math.cos(ang) * radius, z + Math.sin(ang) * radius]);
    }
    var geo = new THREE.BufferGeometry();
    var pos = [];
    for (var i = 0; i < pts.length; i++) {
      var h = this.builder.heightAt(pts[i][0], pts[i][1]);
      pos.push(pts[i][0] - w * 0.5, (h + 0.9) * scale, pts[i][1] - l * 0.5);
    }
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.add(new THREE.Line(geo, new THREE.LineBasicMaterial({ color: color || '#7fd1ff', transparent: true, opacity: 0.95 })));
    var hh = this.builder.heightAt(x, z);
    var dot = new THREE.Mesh(new THREE.SphereGeometry(2.6, 8, 6), new THREE.MeshBasicMaterial({ color: color || '#7fd1ff' }));
    dot.position.set(x - w * 0.5, (hh + 1.2) * scale, z - l * 0.5);
    g.add(dot);
  };

  SceneView.prototype.clearPreview = function () {
    clearGroup(this.groups.preview);
  };

  SceneView.prototype.render = function () {
    var dt = this.clock.getDelta();
    this.time += dt;
    if (this.anim) {
      this.anim.t = Math.min(1, this.anim.t + dt * 2.4);
      var t = this.anim.t;
      var e = t * t * (3 - 2 * t);
      this.target.lerpVectors(this.anim.fromTarget, this.anim.toTarget, e);
      this.spherical.radius = lerp(this.anim.fromSpherical.radius, this.anim.toSpherical.radius, e);
      this.spherical.phi = lerp(this.anim.fromSpherical.phi, this.anim.toSpherical.phi, e);
      this.spherical.theta = lerp(this.anim.fromSpherical.theta, this.anim.toSpherical.theta, e);
      this.updateCamera();
      if (this.anim.t >= 1) this.anim = null;
    }
    for (var i = 0; i < this.waterUniforms.length; i++) {
      this.waterUniforms[i].uTime.value = this.time;
    }
    this.renderer.render(this.scene, this.camera);
  };

  global.CHILL.SceneView = SceneView;
})(window);
