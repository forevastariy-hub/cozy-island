/* CHILL ISLAND MAP EDITOR - application state, tools, panels and persistence */
(function (global) {
  'use strict';

  var Data = global.CHILL.Data;
  var Geo = global.CHILL.Geo;
  var Validator = global.CHILL.Validator;

  var LS_AUTOSAVE = 'chill-island-map-editor:autosave:v1';
  var LS_VERSIONS = 'chill-island-map-editor:versions:v1';

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  function esc(v) {
    return String(v == null ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function timeStr(ts) {
    var d = new Date(ts);
    return d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }

  function dateStr(ts) {
    var d = new Date(ts);
    return d.toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
  }

  function labelOf(map, key, fallback) {
    return (map[key] && map[key].label) || fallback || key;
  }

  function getPath(obj, path) {
    var v = obj;
    for (var i = 0; i < path.length; i++) {
      if (v == null) return undefined;
      v = v[path[i]];
    }
    return v;
  }

  function setPath(obj, path, value) {
    var v = obj;
    for (var i = 0; i < path.length - 1; i++) {
      if (v[path[i]] == null) v[path[i]] = {};
      v = v[path[i]];
    }
    v[path[path.length - 1]] = value;
  }

  var state = null;
  var scene = null;
  var canvas = null;
  var viewport = null;

  var ui = {};

  function init() {
    canvas = $('#view');
    viewport = $('#viewport');
    ui.toolbar = $('#toolbar');
    ui.inspector = $('#inspector');
    ui.issues = $('#issues');
    ui.objects = $('#objects');
    ui.layers = $('#layers');
    ui.toolOptions = $('#toolOptions');
    ui.coords = $('#coords');
    ui.hint = $('#hint');
    ui.issueBadge = $('#issueBadge');
    ui.saveState = $('#saveState');
    ui.mapTitle = $('#mapTitle');
    ui.drawHud = $('#drawHud');
    ui.drawCount = $('#drawCount');
    ui.toast = $('#toast');
    ui.heightScale = $('#heightScale');
    ui.heightScaleOut = $('#heightScaleOut');
    ui.versions = $('#versions');
    ui.exportModal = $('#exportModal');
    ui.exportSummary = $('#exportSummary');
    ui.exportIssues = $('#exportIssues');
    ui.exportJson = $('#exportJson');
    ui.fileInput = $('#fileInput');

    var data;
    try {
      data = loadAutosave();
    } catch (err) {
      data = Data.defaultData();
    }

    state = {
      data: data,
      builder: null,
      selection: null,
      handle: null,
      tool: 'select',
      view: { heightScale: 1.8, mode: data.map.camera.type || 'isometric' },
      layers: {
        grid: true, water: true, zoneFill: true, zoneBorders: true,
        rivers: true, roads: true, landmarks: true, vegetation: true,
        terrainEdits: true, coastline: true, labels: true, handles: true
      },
      toolOptions: {
        zoneType: 'forest', zoneDensity: 0.7,
        landmarkType: 'lookout', vegetationType: 'tree_pine',
        editType: 'hill', brushRadius: 120,
        riverWidth: 7, roadWidth: 7
      },
      draw: null,
      drag: null,
      nav: null,
      preEdit: null,
      undo: [],
      redo: [],
      issues: [],
      dirty: false,
      autosaveTimer: null,
      validateTimer: null,
      rebuildQueued: false,
      versionList: []
    };

    scene = new CHILL.SceneView(canvas);
    state.builder = new CHILL.TerrainBuilder(state.data);
    resize();
    scene.rebuild(state.data, state.builder, state);
    scene.setViewMode(state.view.mode, true);

    renderLayers();
    renderToolOptions();
    updateToolUI();
    renderObjects();
    renderInspector();
    renderVersions();
    updateHistoryButtons();
    updateSaveState();
    updateMapTitle();
    bindEvents();
    runValidation();
    requestAnimationFrame(tick);

    if (window.ResizeObserver) {
      new ResizeObserver(resize).observe(viewport);
    } else {
      window.addEventListener('resize', resize);
    }

    setTimeout(function () {
      if (ui.heightScale) {
        ui.heightScale.value = state.view.heightScale;
        ui.heightScaleOut.textContent = state.view.heightScale.toFixed(1);
      }
    }, 0);
  }

  function tick() {
    scene.render();
    requestAnimationFrame(tick);
  }

  function resize() {
    if (!scene || !viewport) return;
    var r = viewport.getBoundingClientRect();
    if (r.width > 0 && r.height > 0) scene.setSize(r.width, r.height);
  }

  /* persistence */

  function loadAutosave() {
    try {
      var raw = localStorage.getItem(LS_AUTOSAVE);
      if (!raw) return Data.defaultData();
      var parsed = JSON.parse(raw);
      if (parsed && parsed.data) return Data.normalize(parsed.data);
    } catch (err) {
      console.warn('Autosave load failed', err);
    }
    return Data.defaultData();
  }

  function scheduleAutosave() {
    clearTimeout(state.autosaveTimer);
    state.autosaveTimer = setTimeout(saveAutosave, 1100);
  }

  function saveAutosave() {
    if (!state) return;
    try {
      localStorage.setItem(LS_AUTOSAVE, JSON.stringify({ savedAt: Date.now(), data: Data.exportData(state.data) }));
      state.dirty = false;
      updateSaveState();
    } catch (err) {
      toast('Не удалось сохранить автосохранение: ' + err.message, 'error');
    }
  }

  function markDirty() {
    state.dirty = true;
    updateSaveState();
    scheduleAutosave();
  }

  function updateSaveState() {
    if (!ui.saveState) return;
    if (state.dirty) {
      ui.saveState.textContent = 'Не сохранено…';
      ui.saveState.className = 'save-state dirty';
    } else {
      ui.saveState.textContent = 'Автосохранение включено';
      ui.saveState.className = 'save-state';
    }
  }

  function updateMapTitle() {
    if (ui.mapTitle) ui.mapTitle.textContent = state.data.map.name || 'Cozy Island';
    document.title = (state.data.map.name || 'Cozy Island') + ' — CHILL ISLAND MAP EDITOR';
  }

  function renderVersions() {
    try {
      state.versionList = JSON.parse(localStorage.getItem(LS_VERSIONS) || '[]');
      if (!Array.isArray(state.versionList)) state.versionList = [];
    } catch (err) {
      state.versionList = [];
    }
    var html = '<option value="">Версии…</option>';
    for (var i = 0; i < state.versionList.length; i++) {
      var v = state.versionList[i];
      html += '<option value="' + esc(v.id) + '">' + esc(v.name) + ' · ' + esc(dateStr(v.savedAt)) + '</option>';
    }
    ui.versions.innerHTML = html;
  }

  function saveVersion() {
    var def = state.data.map.name + ' — ' + dateStr(Date.now());
    var name = window.prompt('Название версии', def);
    if (!name) return;
    var v = {
      id: 'v_' + Date.now().toString(36) + '_' + Math.floor(Math.random() * 9999).toString(36),
      name: name.trim() || def,
      savedAt: Date.now(),
      data: Data.exportData(state.data)
    };
    state.versionList.unshift(v);
    if (state.versionList.length > 12) state.versionList.length = 12;
    try {
      localStorage.setItem(LS_VERSIONS, JSON.stringify(state.versionList));
      renderVersions();
      toast('Версия сохранена: ' + v.name, 'ok');
    } catch (err) {
      toast('Не удалось сохранить версию: ' + err.message, 'error');
    }
  }

  function loadVersion(id) {
    var v = state.versionList.find(function (x) { return x.id === id; });
    if (!v) return;
    if (state.dirty && !window.confirm('Загрузить версию «' + v.name + '»? Текущие изменения не сохранены.')) {
      ui.versions.value = '';
      return;
    }
    replaceData(v.data, true);
    toast('Загружена версия: ' + v.name, 'ok');
    ui.versions.value = '';
  }

  /* history */

  function pushHistory() {
    state.undo.push(Geo.deepClone(state.data));
    if (state.undo.length > 80) state.undo.shift();
    state.redo = [];
    updateHistoryButtons();
  }

  function commitPreEdit() {
    if (state.preEdit && JSON.stringify(state.preEdit) !== JSON.stringify(state.data)) {
      state.undo.push(state.preEdit);
      if (state.undo.length > 80) state.undo.shift();
      state.redo = [];
      updateHistoryButtons();
    }
    state.preEdit = null;
  }

  function undo() {
    if (!state.undo.length) return;
    state.redo.push(Geo.deepClone(state.data));
    var snapshot = state.undo.pop();
    applySnapshot(snapshot);
    toast('Отменено', 'ok');
  }

  function redo() {
    if (!state.redo.length) return;
    state.undo.push(Geo.deepClone(state.data));
    var snapshot = state.redo.pop();
    applySnapshot(snapshot);
    toast('Повторено', 'ok');
  }

  function applySnapshot(snapshot) {
    state.data = Data.normalize(snapshot);
    state.preEdit = null;
    state.draw = null;
    state.drag = null;
    state.handle = null;
    syncSelection();
    rebuildScene();
    renderObjects();
    renderInspector();
    updateMapTitle();
    scheduleValidate();
    markDirty();
    updateHistoryButtons();
  }

  function updateHistoryButtons() {
    var u = $('#btnUndo'), r = $('#btnRedo');
    if (u) u.disabled = !state.undo.length;
    if (r) r.disabled = !state.redo.length;
  }

  /* scene rebuilding */

  function rebuildScene() {
    state.builder = new CHILL.TerrainBuilder(state.data);
    scene.rebuild(state.data, state.builder, state);
  }

  function fastRebuild() {
    markDirty();
    if (state.rebuildQueued) return;
    state.rebuildQueued = true;
    requestAnimationFrame(function () {
      state.rebuildQueued = false;
      if (!state) return;
      rebuildScene();
      scheduleValidate();
    });
  }

  function structuralRebuild() {
    rebuildScene();
    syncSelection();
    renderObjects();
    renderInspector();
    updateMapTitle();
    scheduleValidate();
    markDirty();
  }

  function scheduleValidate() {
    clearTimeout(state.validateTimer);
    state.validateTimer = setTimeout(runValidation, 180);
  }

  function runValidation() {
    if (!state || !state.builder) return;
    state.issues = Validator.validate(state.data, state.builder);
    renderIssues();
  }

  function replaceData(raw, fit) {
    var normalized;
    try {
      normalized = Data.normalize(raw);
    } catch (err) {
      toast('Не удалось загрузить карту: ' + err.message, 'error');
      return false;
    }
    state.data = normalized;
    state.selection = null;
    state.handle = null;
    state.draw = null;
    state.drag = null;
    state.undo = [];
    state.redo = [];
    state.preEdit = null;
    state.builder = new CHILL.TerrainBuilder(state.data);
    scene.rebuild(state.data, state.builder, state);
    if (fit !== false) scene.fitView();
    scene.setViewMode(state.data.map.camera.type || 'isometric', true);
    state.view.mode = state.data.map.camera.type || 'isometric';
    renderObjects();
    renderInspector();
    updateMapTitle();
    updateHistoryButtons();
    updateToolUI();
    runValidation();
    markDirty();
    return true;
  }

  /* selection */

  function getSelected() {
    if (!state.selection) return null;
    var sel = state.selection;
    if (sel.kind === 'zone') return state.data.zones.find(function (z) { return z.id === sel.id; }) || null;
    if (sel.kind === 'river') return state.data.rivers.find(function (r) { return r.id === sel.id; }) || null;
    if (sel.kind === 'road') return state.data.roads.find(function (r) { return r.id === sel.id; }) || null;
    if (sel.kind === 'landmark') return state.data.landmarks.find(function (l) { return l.id === sel.id; }) || null;
    if (sel.kind === 'vegetation') return state.data.vegetation.find(function (v) { return v.id === sel.id; }) || null;
    if (sel.kind === 'terrainEdit') return (state.data.terrain.edits || []).find(function (e) { return e.id === sel.id; }) || null;
    if (sel.kind === 'coast') return state.data.terrain.coast;
    return null;
  }

  function syncSelection() {
    if (state.selection && !getSelected()) state.selection = null;
    if (state.handle && (!state.selection || state.handle.kind !== state.selection.kind || state.handle.id !== state.selection.id)) {
      state.handle = null;
    }
  }

  function select(kind, id, focus) {
    state.selection = kind ? { kind: kind, id: id } : null;
    state.handle = null;
    rebuildScene();
    renderInspector();
    renderObjects();
    if (focus && state.selection) focusSelected();
  }

  function focusSelected() {
    if (!state.selection) return;
    var sel = state.selection;
    var x, z, r = 160;
    if (sel.kind === 'zone') {
      var zone = getSelected();
      if (!zone) return;
      var c = Geo.polygonCentroid(zone.points);
      x = c[0]; z = c[1]; r = Math.max(zone.size[0], zone.size[1]) * 0.7;
    } else if (sel.kind === 'river' || sel.kind === 'road') {
      var line = getSelected();
      if (!line || !line.points.length) return;
      var p = line.points[Math.floor(line.points.length / 2)];
      x = p[0]; z = p[1];
      var bbox = Geo.polygonBBox(line.points);
      r = Math.max(bbox.maxX - bbox.minX, bbox.maxZ - bbox.minZ) * 0.6 + 80;
    } else if (sel.kind === 'landmark' || sel.kind === 'vegetation') {
      var obj = getSelected();
      if (!obj) return;
      x = obj.position[0]; z = obj.position[1]; r = 130;
    } else if (sel.kind === 'terrainEdit') {
      var e = getSelected();
      if (!e) return;
      x = e.center[0]; z = e.center[1]; r = e.radius * 1.4;
    } else if (sel.kind === 'coast') {
      x = state.data.map.size.width * 0.5;
      z = state.data.map.size.length * 0.5;
      r = Math.max(state.data.map.size.width, state.data.map.size.length) * 0.9;
    }
    if (x != null) scene.focus(x, z, r);
  }

  function deleteSelection() {
    if (!state.selection) return;
    var sel = state.selection;
    var arr, idx;
    if (sel.kind === 'zone') arr = state.data.zones;
    else if (sel.kind === 'river') arr = state.data.rivers;
    else if (sel.kind === 'road') arr = state.data.roads;
    else if (sel.kind === 'landmark') arr = state.data.landmarks;
    else if (sel.kind === 'vegetation') arr = state.data.vegetation;
    else if (sel.kind === 'terrainEdit') arr = state.data.terrain.edits;
    else {
      toast('Берег нельзя удалить — используйте «Пересоздать берег».', 'warn');
      return;
    }
    idx = arr.findIndex(function (o) { return o.id === sel.id; });
    if (idx < 0) return;
    pushHistory();
    arr.splice(idx, 1);
    var label = sel.kind;
    state.selection = null;
    state.handle = null;
    structuralRebuild();
    toast('Удалено: ' + label, 'ok');
  }

  function syncZoneMeta(z) {
    if (!z || !z.points || z.points.length < 3) return;
    z.center = Geo.polygonCentroid(z.points);
    z.size = Geo.polygonSize(z.points);
  }

  /* inspector */

  function inpRoot(root, prop, type, value, extra) {
    var v = value == null ? '' : value;
    var step = '';
    if (type === 'number') step = ' step="' + (extra && extra.step ? extra.step : 'any') + '"';
    return '<input class="inp" data-root="' + root + '" data-prop="' + prop + '" type="' + type + '"' + step +
      (extra && extra.deg ? ' data-deg="1"' : '') +
      (extra && extra.optional ? ' data-optional="1"' : '') +
      (extra && extra.disabled ? ' disabled' : '') +
      ' value="' + esc(v) + '">';
  }

  function textInp(root, prop, value, extra) {
    return '<input class="inp" data-root="' + root + '" data-prop="' + prop + '" type="text" value="' + esc(value) + '">';
  }

  function numInp(root, prop, value, extra) {
    return inpRoot(root, prop, 'number', value, extra);
  }

  function rangeInp(root, prop, value, min, max, step, extra) {
    return '<div class="range-wrap"><input class="range" data-root="' + root + '" data-prop="' + prop + '" type="range" min="' + min + '" max="' + max + '" step="' + step + '" value="' + esc(value) + '">' +
      '<output>' + esc(Geo.round(Number(value) || 0, 2)) + '</output></div>';
  }

  function selectInp(root, prop, value, options) {
    var html = '<select class="inp" data-root="' + root + '" data-prop="' + prop + '">';
    for (var key in options) {
      if (!Object.prototype.hasOwnProperty.call(options, key)) continue;
      html += '<option value="' + esc(key) + '"' + (key === value ? ' selected' : '') + '>' + esc(labelOf(options, key)) + '</option>';
    }
    return html + '</select>';
  }

  function checkInp(root, prop, checked, text) {
    return '<label class="check"><input type="checkbox" data-root="' + root + '" data-prop="' + prop + '"' + (checked ? ' checked' : '') + '><span>' + esc(text) + '</span></label>';
  }

  function row(label, control) {
    return '<label class="field"><span class="flabel">' + esc(label) + '</span>' + control + '</label>';
  }

  function section(title) {
    return '<div class="section-title">' + esc(title) + '</div>';
  }

  function btn(action, text, cls) {
    return '<button class="btn small ' + (cls || '') + '" data-action="' + action + '">' + esc(text) + '</button>';
  }

  function bindInspector() {
    var container = ui.inspector;
    $$('[data-prop]', container).forEach(function (inp) {
      var rootName = inp.getAttribute('data-root') || 'obj';
      var root;
      if (rootName === 'map') root = state.data.map;
      else if (rootName === 'terrain') root = state.data.terrain;
      else if (rootName === 'data') root = state.data;
      else root = getSelected();
      if (!root) return;
      var path = inp.getAttribute('data-prop').split('.');
      var isDeg = inp.hasAttribute('data-deg');
      var optional = inp.hasAttribute('data-optional');

      var current = getPath(root, path);
      if (isDeg) current = current == null ? 0 : Geo.round(current * 180 / Math.PI, 1);
      if (optional && current == null) current = '';
      if (inp.type === 'checkbox') inp.checked = !!getPath(root, path);
      else if (document.activeElement !== inp) inp.value = current == null ? '' : current;

      function updateOut() {
        if (inp.type !== 'range') return;
        var out = inp.parentNode.querySelector('output');
        if (out) out.textContent = Geo.round(Number(inp.value) || 0, 2);
      }
      updateOut();

      function apply() {
        var raw;
        if (inp.type === 'checkbox') raw = inp.checked;
        else if (inp.type === 'number' || inp.type === 'range') raw = inp.value === '' ? null : Number(inp.value);
        else raw = inp.value;
        if (optional && (raw === '' || raw == null)) raw = null;
        if (isDeg) raw = raw == null ? 0 : raw * Math.PI / 180;
        var old = getPath(root, path);
        setPath(root, path, raw);
        afterFieldChange(root, path, old, raw);
        updateOut();
        fastRebuild();
        if (root === state.data.map && path[0] === 'name') updateMapTitle();
        if (root !== state.data.map && path[0] === 'name') {
          var heading = ui.inspector.querySelector('.inspector-head h2');
          if (heading) heading.textContent = raw == null ? '' : String(raw);
          renderObjects();
        }
      }

      if (inp.type === 'select' || inp.type === 'checkbox') {
        inp.addEventListener('change', function () {
          pushHistory();
          apply();
          structuralRebuild();
        });
      } else {
        inp.addEventListener('focus', function () {
          state.preEdit = Geo.deepClone(state.data);
        });
        inp.addEventListener('input', apply);
        inp.addEventListener('change', function () {
          commitPreEdit();
          if (root === state.data.map && path[0] === 'name') renderInspector();
          scheduleValidate();
        });
      }
    });
  }

  function afterFieldChange(root, path, oldVal, newVal) {
    if (!state.selection || state.selection.kind !== 'zone') return;
    var z = getSelected();
    if (!z || root !== z) return;
    if (path[0] === 'center' && path[1] === '0') {
      Geo.movePolygon(z.points, (newVal || 0) - (oldVal || 0), 0);
      syncZoneMeta(z);
    } else if (path[0] === 'center' && path[1] === '1') {
      Geo.movePolygon(z.points, 0, (newVal || 0) - (oldVal || 0));
      syncZoneMeta(z);
    } else if (path[0] === 'size' && path[1] === '0') {
      var rx = oldVal > 0.001 ? (newVal || 1) / oldVal : 1;
      Geo.scalePolygon(z.points, z.center[0], z.center[1], rx, 1);
      syncZoneMeta(z);
    } else if (path[0] === 'size' && path[1] === '1') {
      var rz = oldVal > 0.001 ? (newVal || 1) / oldVal : 1;
      Geo.scalePolygon(z.points, z.center[0], z.center[1], 1, rz);
      syncZoneMeta(z);
    } else if (path[0] === 'rotation') {
      var delta = (newVal || 0) - (oldVal || 0);
      for (var i = 0; i < z.points.length; i++) {
        z.points[i] = Geo.rotateAround(z.points[i][0], z.points[i][1], z.center[0], z.center[1], delta);
      }
      syncZoneMeta(z);
    }
  }

  function renderInspector() {
    if (!ui.inspector) return;
    var sel = state.selection;
    if (!sel) {
      renderMapInspector();
      return;
    }
    var obj = getSelected();
    if (!obj) {
      state.selection = null;
      renderMapInspector();
      return;
    }

    var html = '';
    if (sel.kind === 'zone') html = zoneInspector(obj);
    else if (sel.kind === 'river') html = riverInspector(obj);
    else if (sel.kind === 'road') html = roadInspector(obj);
    else if (sel.kind === 'coast') html = coastInspector(obj);
    else if (sel.kind === 'terrainEdit') html = editInspector(obj);
    else if (sel.kind === 'landmark') html = landmarkInspector(obj);
    else if (sel.kind === 'vegetation') html = vegetationInspector(obj);

    ui.inspector.innerHTML = html;
    bindInspector();
  }

  function renderMapInspector() {
    var d = state.data;
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(d.map.name) + '</h2><div class="sub">Карта острова · ' + d.zones.length + ' зон · ' + d.rivers.length + ' рек</div></div></div>';
    html += section('Основное');
    html += row('Название', textInp('map', 'name', d.map.name));
    html += row('Seed', numInp('map', 'seed', d.map.seed, { step: '1' }));
    html += '<div class="grid2">' +
      row('Ширина', numInp('map', 'size.0', d.map.size.width, { step: '1' })) +
      row('Длина', numInp('map', 'size.1', d.map.size.length, { step: '1' })) +
      row('Макс. высота', numInp('map', 'size.2', d.map.size.maxHeight, { step: '1' })) +
      '</div>';
    html += section('Рельеф');
    html += row('Базовая высота', rangeInp('terrain', 'baseHeight', d.terrain.baseHeight, 0, 60, 0.5));
    html += row('Сила холмов', rangeInp('terrain', 'hillStrength', d.terrain.hillStrength, 0, 120, 1));
    html += row('Шероховатость', rangeInp('terrain', 'roughness', d.terrain.roughness, 0, 1, 0.01));
    html += row('Смешивание берега', rangeInp('terrain', 'coastBlend', d.terrain.coastBlend, 2, 100, 1));
    html += row('Уровень воды', rangeInp('terrain', 'waterLevel', d.terrain.waterLevel, -5, 12, 0.1));
    html += section('Берег');
    html += '<div class="muted">Вершин: ' + d.terrain.coast.points.length + '</div>';
    html += '<div class="btn-row">' + btn('regenCoast', 'Пересоздать берег') + btn('fitView', 'Вписать вид') + '</div>';
    html += section('Слои и объекты');
    html += '<div class="stats">' +
      stat('Зоны', d.zones.length) + stat('Реки', d.rivers.length) + stat('Дороги', d.roads.length) +
      stat('Объекты', d.landmarks.length) + stat('Растительность', d.vegetation.length) +
      stat('Правки', d.terrain.edits.length) + '</div>';
    html += '<div class="muted small-note">Выберите объект в списке слева или кликните по нему в 3D.</div>';
    ui.inspector.innerHTML = html;
    bindInspector();
  }

  function stat(label, value) {
    return '<div class="stat"><span>' + esc(label) + '</span><b>' + esc(value) + '</b></div>';
  }

  function zoneInspector(z) {
    var options = Data.ZONE_TYPES;
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(z.name) + '</h2><div class="sub">Зона · ' + esc(labelOf(options, z.type)) + '</div></div></div>';
    html += section('Основное');
    html += row('Название', textInp('obj', 'name', z.name));
    html += row('Тип', selectInp('obj', 'type', z.type, options));
    html += '<div class="grid2">' +
      row('Центр X', numInp('obj', 'center.0', Geo.round(z.center[0], 1), { step: '1' })) +
      row('Центр Z', numInp('obj', 'center.1', Geo.round(z.center[1], 1), { step: '1' })) +
      row('Размер X', numInp('obj', 'size.0', Geo.round(z.size[0], 1), { step: '1' })) +
      row('Размер Z', numInp('obj', 'size.1', Geo.round(z.size[1], 1), { step: '1' })) +
      '</div>';
    html += row('Поворот, °', numInp('obj', 'rotation', Geo.round((z.rotation || 0) * 180 / Math.PI, 1), { step: '1', deg: true }));
    html += row('Плотность', rangeInp('obj', 'density', z.density, 0, 1, 0.01));
    if (z.type === 'lake' || z.type === 'swamp') {
      html += row('Уровень воды', numInp('obj', 'waterLevel', Geo.round(z.waterLevel, 2), { step: '0.1' }));
    }
    html += '<div class="muted">Вершин полигона: ' + z.points.length + '</div>';
    html += section('Действия');
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('addVertex', 'Добавить вершину') + btn('delete', 'Удалить зону', 'danger') + '</div>';
    html += '<div class="muted small-note">Тяните голубые маркеры в 3D или белый маркер в центре, чтобы двигать зону.</div>';
    return html;
  }

  function riverInspector(r) {
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(r.name) + '</h2><div class="sub">Река · ' + r.points.length + ' контрольных точек</div></div></div>';
    html += section('Форма русла');
    html += row('Название', textInp('obj', 'name', r.name));
    html += '<div class="grid2">' +
      row('Ширина', numInp('obj', 'width', Geo.round(r.width, 2), { step: '0.1' })) +
      row('Глубина', numInp('obj', 'depth', Geo.round(r.depth, 2), { step: '0.05' })) +
      row('Ширина берега', numInp('obj', 'bankWidth', Geo.round(r.bankWidth, 2), { step: '0.1' })) +
      '</div>';
    html += row('Сечение', selectInp('obj', 'crossSection', r.crossSection, Data.CROSS_SECTIONS));
    html += row('Переход берега', selectInp('obj', 'bankTransition', r.bankTransition, Data.BANK_TRANSITIONS));
    html += row('Сглаживание', rangeInp('obj', 'smoothness', r.smoothness, 0, 1, 0.01));
    html += row('Направление течения', selectInp('obj', 'flowDirection', r.flowDirection, Data.FLOW_DIRECTIONS));
    html += section('Вода');
    html += checkInp('obj', 'autoWater', r.autoWater, 'Высота воды по рельефу');
    html += row('Высота воды', numInp('obj', 'waterHeight', Geo.round(r.waterHeight, 2), { step: '0.1', disabled: r.autoWater }));
    html += section('Действия');
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('addLinePoint', 'Точка в конец') + btn('removeLinePoint', 'Убрать точку') + btn('reverseLine', 'Развернуть') + btn('delete', 'Удалить реку', 'danger') + '</div>';
    html += '<div class="muted small-note">Инструмент «Река»: ЛКМ добавляет точки, ПКМ/Enter завершает. Маркеры точек тянутся в 3D.</div>';
    return html;
  }

  function roadInspector(r) {
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(r.name) + '</h2><div class="sub">Дорога · ' + r.points.length + ' контрольных точек</div></div></div>';
    html += section('Параметры');
    html += row('Название', textInp('obj', 'name', r.name));
    html += row('Тип', textInp('obj', 'type', r.type));
    html += '<div class="grid2">' +
      row('Ширина', numInp('obj', 'width', Geo.round(r.width, 2), { step: '0.1' })) +
      '</div>';
    html += row('Сглаживание', rangeInp('obj', 'smoothness', r.smoothness, 0, 1, 0.01));
    html += section('Действия');
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('addLinePoint', 'Точка в конец') + btn('removeLinePoint', 'Убрать точку') + btn('reverseLine', 'Развернуть') + btn('delete', 'Удалить дорогу', 'danger') + '</div>';
    html += '<div class="muted small-note">Инструмент «Дорога»: ЛКМ добавляет точки, ПКМ/Enter завершает. Маркеры точек тянутся в 3D.</div>';
    return html;
  }

  function coastInspector(c) {
    var html = '';
    html += '<div class="inspector-head"><div><h2>Береговая линия</h2><div class="sub">Контур острова · ' + c.points.length + ' вершин</div></div></div>';
    html += section('Редактирование');
    html += '<div class="muted small-note">Выберите маркеры вершин и тяните их. Контур задаёт форму острова и пляжа.</div>';
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('addCoastVertex', 'Добавить вершину') + btn('regenCoast', 'Пересоздать берег', 'danger') + '</div>';
    if (state.handle && state.handle.kind === 'coast' && state.handle.part === 'point') {
      html += '<div class="muted">Выбрана вершина #' + state.handle.index + '</div>';
    }
    html += section('Совет');
    html += '<div class="muted small-note">После изменения размера карты пересоздайте берег, чтобы контур соответствовал новым границам.</div>';
    return html;
  }

  function editInspector(e) {
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(e.id) + '</h2><div class="sub">Правка рельефа · ' + esc(e.type) + '</div></div></div>';
    html += section('Правка');
    html += row('Тип', selectInp('obj', 'type', e.type, { hill: { label: 'Холм' }, depression: { label: 'Впадина' }, plateau: { label: 'Плато' }, cliff: { label: 'Обрыв' } }));
    html += '<div class="grid2">' +
      row('Центр X', numInp('obj', 'center.0', Geo.round(e.center[0], 1), { step: '1' })) +
      row('Центр Z', numInp('obj', 'center.1', Geo.round(e.center[1], 1), { step: '1' })) +
      '</div>';
    html += row('Радиус', rangeInp('obj', 'radius', e.radius, 10, 600, 1));
    html += row('Высота', rangeInp('obj', 'height', e.height, -80, 120, 1));
    html += row('Плавность', rangeInp('obj', 'falloff', e.falloff, 0.05, 1, 0.01));
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('delete', 'Удалить правку', 'danger') + '</div>';
    return html;
  }

  function landmarkInspector(lm) {
    var info = Data.LANDMARK_TYPES[lm.type] || Data.LANDMARK_TYPES.point;
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(lm.name) + '</h2><div class="sub">Объект · ' + esc(info.label) + '</div></div></div>';
    html += section('Объект');
    html += row('Название', textInp('obj', 'name', lm.name));
    html += row('Тип', selectInp('obj', 'type', lm.type, Data.LANDMARK_TYPES));
    html += '<div class="grid2">' +
      row('X', numInp('obj', 'position.0', Geo.round(lm.position[0], 1), { step: '1' })) +
      row('Z', numInp('obj', 'position.1', Geo.round(lm.position[1], 1), { step: '1' })) +
      '</div>';
    html += row('Поворот, °', numInp('obj', 'rotation', Geo.round((lm.rotation || 0) * 180 / Math.PI, 1), { step: '1', deg: true }));
    html += row('Масштаб', rangeInp('obj', 'scale', lm.scale, 0.2, 5, 0.05));
    html += row('Высота (пусто = авто)', numInp('obj', 'elevation', lm.elevation == null ? '' : Geo.round(lm.elevation, 2), { step: '0.1', optional: true }));
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('delete', 'Удалить объект', 'danger') + '</div>';
    html += '<div class="muted small-note">Инструмент «Объект» ставит выбранный тип по клику.</div>';
    return html;
  }

  function vegetationInspector(v) {
    var info = Data.VEGETATION_TYPES[v.type] || Data.VEGETATION_TYPES.tree_pine;
    var html = '';
    html += '<div class="inspector-head"><div><h2>' + esc(v.name || info.label) + '</h2><div class="sub">Растительность · ' + esc(info.label) + '</div></div></div>';
    html += section('Растительность');
    html += row('Название', textInp('obj', 'name', v.name));
    html += row('Тип', selectInp('obj', 'type', v.type, Data.VEGETATION_TYPES));
    html += '<div class="grid2">' +
      row('X', numInp('obj', 'position.0', Geo.round(v.position[0], 1), { step: '1' })) +
      row('Z', numInp('obj', 'position.1', Geo.round(v.position[1], 1), { step: '1' })) +
      '</div>';
    html += row('Поворот, °', numInp('obj', 'rotation', Geo.round((v.rotation || 0) * 180 / Math.PI, 1), { step: '1', deg: true }));
    html += row('Масштаб', rangeInp('obj', 'scale', v.scale, 0.2, 4, 0.05));
    html += '<div class="btn-row">' + btn('focus', 'Показать') + btn('delete', 'Удалить', 'danger') + '</div>';
    return html;
  }

  /* panels */

  function renderLayers() {
    var defs = [
      ['grid', 'Сетка'], ['water', 'Вода'], ['zoneFill', 'Заливка зон'], ['zoneBorders', 'Границы зон'],
      ['rivers', 'Реки'], ['roads', 'Дороги'], ['landmarks', 'Объекты'], ['vegetation', 'Растительность'],
      ['terrainEdits', 'Рельефные правки'], ['coastline', 'Берег'], ['labels', 'Подписи'], ['handles', 'Маркеры']
    ];
    var html = '';
    defs.forEach(function (d) {
      html += '<label class="layer"><input type="checkbox" data-layer="' + d[0] + '"' + (state.layers[d[0]] ? ' checked' : '') + '><span>' + esc(d[1]) + '</span></label>';
    });
    ui.layers.innerHTML = html;
  }

  function renderToolOptions() {
    var html = '';
    html += '<div class="toolopt" data-tools="zone">' +
      '<label class="field"><span class="flabel">Тип зоны</span><select class="inp" id="optZoneType">' + optionsHtml(Data.ZONE_TYPES, state.toolOptions.zoneType) + '</select></label>' +
      '<label class="field"><span class="flabel">Плотность</span><input class="range" id="optZoneDensity" type="range" min="0" max="1" step="0.01" value="' + state.toolOptions.zoneDensity + '"><output id="optZoneDensityOut">' + state.toolOptions.zoneDensity + '</output></label>' +
      '</div>';
    html += '<div class="toolopt" data-tools="landmark">' +
      '<label class="field"><span class="flabel">Тип объекта</span><select class="inp" id="optLandmarkType">' + optionsHtml(Data.LANDMARK_TYPES, state.toolOptions.landmarkType) + '</select></label>' +
      '</div>';
    html += '<div class="toolopt" data-tools="vegetation">' +
      '<label class="field"><span class="flabel">Тип растения</span><select class="inp" id="optVegetationType">' + optionsHtml(Data.VEGETATION_TYPES, state.toolOptions.vegetationType) + '</select></label>' +
      '</div>';
    html += '<div class="toolopt" data-tools="terrain">' +
      '<label class="field"><span class="flabel">Тип правки</span><select class="inp" id="optEditType">' +
      '<option value="hill"' + (state.toolOptions.editType === 'hill' ? ' selected' : '') + '>Холм</option>' +
      '<option value="depression"' + (state.toolOptions.editType === 'depression' ? ' selected' : '') + '>Впадина</option>' +
      '<option value="plateau"' + (state.toolOptions.editType === 'plateau' ? ' selected' : '') + '>Плато</option>' +
      '<option value="cliff"' + (state.toolOptions.editType === 'cliff' ? ' selected' : '') + '>Обрыв</option>' +
      '</select></label>' +
      '<label class="field"><span class="flabel">Радиус кисти</span><input class="range" id="optBrushRadius" type="range" min="20" max="400" step="5" value="' + state.toolOptions.brushRadius + '"><output id="optBrushRadiusOut">' + state.toolOptions.brushRadius + '</output></label>' +
      '</div>';
    html += '<div class="toolopt" data-tools="river">' +
      '<div class="muted small-note">Клик по земле добавляет точку. ПКМ или Enter завершает реку.</div>' +
      '</div>';
    html += '<div class="toolopt" data-tools="road">' +
      '<div class="muted small-note">Клик по земле добавляет точку. ПКМ или Enter завершает дорогу.</div>' +
      '</div>';
    html += '<div class="toolopt" data-tools="coast">' +
      '<div class="muted small-note">Клик по линии берега выбирает контур. Затем тяните маркеры вершин.</div>' +
      '</div>';
    ui.toolOptions.innerHTML = html;

    $('#optZoneType').addEventListener('change', function () { state.toolOptions.zoneType = this.value; });
    $('#optZoneDensity').addEventListener('input', function () {
      state.toolOptions.zoneDensity = Number(this.value);
      $('#optZoneDensityOut').textContent = this.value;
    });
    $('#optLandmarkType').addEventListener('change', function () { state.toolOptions.landmarkType = this.value; });
    $('#optVegetationType').addEventListener('change', function () { state.toolOptions.vegetationType = this.value; });
    $('#optEditType').addEventListener('change', function () { state.toolOptions.editType = this.value; });
    $('#optBrushRadius').addEventListener('input', function () {
      state.toolOptions.brushRadius = Number(this.value);
      $('#optBrushRadiusOut').textContent = this.value;
      if (state.tool === 'terrain') {
        var c = lastCursor;
        if (c) scene.showBrushPreview(c.x, c.z, state.toolOptions.brushRadius, editColor(state.toolOptions.editType));
      }
    });
  }

  function optionsHtml(options, value) {
    var html = '';
    for (var key in options) {
      if (!Object.prototype.hasOwnProperty.call(options, key)) continue;
      html += '<option value="' + esc(key) + '"' + (key === value ? ' selected' : '') + '>' + esc(labelOf(options, key)) + '</option>';
    }
    return html;
  }

  function renderObjects() {
    var d = state.data;
    var sel = state.selection;
    var html = '';
    function item(kind, id, name, meta) {
      var active = sel && sel.kind === kind && sel.id === id;
      return '<button class="obj-item' + (active ? ' active' : '') + '" data-kind="' + kind + '" data-id="' + esc(id) + '" title="' + esc(name) + '">' +
        '<span class="obj-name">' + esc(name) + '</span><span class="obj-meta">' + esc(meta || '') + '</span></button>';
    }
    html += '<div class="obj-group"><div class="obj-title">Зоны <b>' + d.zones.length + '</b></div>';
    d.zones.forEach(function (z) { html += item('zone', z.id, z.name, labelOf(Data.ZONE_TYPES, z.type)); });
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Реки <b>' + d.rivers.length + '</b></div>';
    d.rivers.forEach(function (r) { html += item('river', r.id, r.name, r.points.length + ' т.'); });
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Дороги <b>' + d.roads.length + '</b></div>';
    d.roads.forEach(function (r) { html += item('road', r.id, r.name, r.points.length + ' т.'); });
    if (!d.roads.length) html += '<div class="obj-empty">Нет дорог — нарисуйте инструментом «Дорога».</div>';
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Объекты <b>' + d.landmarks.length + '</b></div>';
    d.landmarks.forEach(function (l) { html += item('landmark', l.id, l.name, labelOf(Data.LANDMARK_TYPES, l.type)); });
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Растительность <b>' + d.vegetation.length + '</b></div>';
    d.vegetation.slice(0, 300).forEach(function (v) { html += item('vegetation', v.id, v.name, labelOf(Data.VEGETATION_TYPES, v.type)); });
    if (d.vegetation.length > 300) html += '<div class="obj-empty">Показаны первые 300 из ' + d.vegetation.length + '</div>';
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Рельеф <b>' + d.terrain.edits.length + '</b></div>';
    d.terrain.edits.forEach(function (e) { html += item('terrainEdit', e.id, e.id, e.type); });
    html += '</div>';
    html += '<div class="obj-group"><div class="obj-title">Берег</div>';
    html += item('coast', 'coastline', 'Береговая линия', d.terrain.coast.points.length + ' в.');
    html += '</div>';
    ui.objects.innerHTML = html;
  }

  function updateToolUI() {
    $$('#toolbar [data-tool]').forEach(function (b) {
      b.classList.toggle('active', b.getAttribute('data-tool') === state.tool);
    });
    $$('.toolopt').forEach(function (opt) {
      var tools = (opt.getAttribute('data-tools') || '').split(',');
      opt.classList.toggle('visible', tools.indexOf(state.tool) >= 0);
    });
    var hints = {
      select: 'ЛКМ — выбрать · маркеры тянутся · СКМ — орбита · Shift+СКМ / ПКМ — панорама · колесо — зум',
      zone: 'ЛКМ — растянуть новую зону (короткий клик — зона по умолчанию)',
      river: 'ЛКМ — точки реки · ПКМ или Enter — завершить · Esc — отмена',
      road: 'ЛКМ — точки дороги · ПКМ или Enter — завершить · Esc — отмена',
      terrain: 'ЛКМ — рельефная правка выбранного типа',
      landmark: 'ЛКМ — поставить объект выбранного типа',
      vegetation: 'ЛКМ — поставить растение выбранного типа',
      coast: 'ЛКМ — выбрать берег · затем тяните маркеры вершин'
    };
    if (ui.hint) ui.hint.textContent = hints[state.tool] || '';
    updateDrawHud();
    if (!state.draw) scene.clearPreview();
  }

  function updateDrawHud() {
    if (!ui.drawHud) return;
    if (!state.draw) {
      ui.drawHud.classList.add('hidden');
      return;
    }
    ui.drawHud.classList.remove('hidden');
    ui.drawCount.textContent = 'Точек: ' + state.draw.points.length;
  }

  /* validation panel */

  function renderIssues() {
    if (!ui.issues) return;
    var s = Validator.summarize(state.issues);
    if (!state.issues.length) {
      ui.issues.innerHTML = '<div class="issues-empty">Проблем не найдено. Можно экспортировать карту.</div>';
    } else {
      var html = '';
      var shown = state.issues.slice(0, 120);
      shown.forEach(function (iss, idx) {
        html += '<button class="issue ' + esc(iss.severity) + '" data-issue="' + idx + '">' +
          '<span class="issue-dot"></span><span class="issue-text">' + esc(iss.message) + '</span></button>';
      });
      if (state.issues.length > shown.length) {
        html += '<div class="obj-empty">Показаны первые ' + shown.length + ' из ' + state.issues.length + '.</div>';
      }
      ui.issues.innerHTML = html;
    }
    updateIssueBadge(s);
  }

  function updateIssueBadge(s) {
    if (!ui.issueBadge) return;
    ui.issueBadge.className = 'issue-badge';
    if (s.errors) {
      ui.issueBadge.classList.add('has-errors');
      ui.issueBadge.textContent = 'Ошибки: ' + s.errors + ' · Предупр.: ' + s.warnings;
    } else if (s.warnings) {
      ui.issueBadge.classList.add('has-warnings');
      ui.issueBadge.textContent = 'Предупреждения: ' + s.warnings;
    } else {
      ui.issueBadge.classList.add('clean');
      ui.issueBadge.textContent = 'Проверки пройдены';
    }
  }

  function issueIndexFromEl(el) {
    var n = Number(el.getAttribute('data-issue'));
    return Number.isFinite(n) ? n : -1;
  }

  /* tools */

  var lastCursor = null;

  function terrainAt(e) {
    return scene.raycastTerrain(e.clientX, e.clientY);
  }

  function editColor(type) {
    return type === 'depression' ? '#5a9fd6' : (type === 'plateau' ? '#d6b95a' : (type === 'cliff' ? '#d77d5a' : '#68c47a'));
  }

  function startNav(e, mode) {
    state.nav = { mode: mode, lastX: e.clientX, lastY: e.clientY, pointerId: e.pointerId };
    canvas.setPointerCapture(e.pointerId);
    e.preventDefault();
  }

  function beginHandleDrag(hit, e) {
    pushHistory();
    state.handle = hit.handle;
    state.selection = { kind: hit.handle.kind, id: hit.handle.id };
    var t = terrainAt(e);
    state.drag = {
      mode: 'handle', handle: hit.handle,
      anchor: t ? { x: t.x, z: t.z } : null,
      pointerId: e.pointerId
    };
    canvas.setPointerCapture(e.pointerId);
    renderInspector();
    renderObjects();
    e.preventDefault();
  }

  function updateHandleDrag(e) {
    var t = terrainAt(e);
    if (!t || !state.drag) return;
    var h = state.drag.handle;
    var sel = state.selection;
    if (!sel) return;
    var x = t.x, z = t.z;

    if (h.part === 'center' && sel.kind === 'zone') {
      var zobj = getSelected();
      if (!zobj) return;
      var dx = state.drag.anchor ? x - state.drag.anchor.x : 0;
      var dz = state.drag.anchor ? z - state.drag.anchor.z : 0;
      if (dx || dz) {
        Geo.movePolygon(zobj.points, dx, dz);
        zobj.center = [zobj.center[0] + dx, zobj.center[1] + dz];
        state.drag.anchor = { x: x, z: z };
      }
    } else if ((h.part === 'center' || h.part === 'position') && sel.kind === 'terrainEdit') {
      var edit = getSelected();
      if (edit) edit.center = [x, z];
    } else if ((h.part === 'center' || h.part === 'position') && (sel.kind === 'landmark' || sel.kind === 'vegetation')) {
      var obj = getSelected();
      if (obj) obj.position = [x, z];
    } else if (h.part === 'point' && h.index >= 0) {
      if (sel.kind === 'zone') {
        var zone = getSelected();
        if (zone && zone.points[h.index]) {
          zone.points[h.index] = [x, z];
          syncZoneMeta(zone);
        }
      } else if (sel.kind === 'river' || sel.kind === 'road') {
        var line = getSelected();
        if (line && line.points[h.index]) line.points[h.index] = [x, z];
      } else if (sel.kind === 'coast') {
        if (state.data.terrain.coast.points[h.index]) state.data.terrain.coast.points[h.index] = [x, z];
      }
    }
    fastRebuild();
  }

  function updateCursor(e) {
    var t = terrainAt(e);
    if (!t) return;
    lastCursor = t;
    if (ui.coords) ui.coords.textContent = 'X ' + Geo.round(t.x, 0) + '   Z ' + Geo.round(t.z, 0) + '   H ' + Geo.round(t.height, 1);
    if (state.tool === 'terrain' && !state.drag) {
      scene.showBrushPreview(t.x, t.z, state.toolOptions.brushRadius, editColor(state.toolOptions.editType));
    }
  }

  function addDrawPoint(e) {
    var t = terrainAt(e);
    if (!t) return;
    if (!state.draw) state.draw = { kind: state.tool, points: [] };
    state.draw.points.push([t.x, t.z]);
    scene.showDrawPreview(state.draw.points, null, state.draw.kind);
    updateDrawHud();
    e.preventDefault();
  }

  function finishDraw() {
    if (!state.draw) return;
    var draw = state.draw;
    if (draw.points.length < 2) {
      toast('Нужно минимум две точки.', 'warn');
      return;
    }
    pushHistory();
    var count = draw.kind === 'river' ? state.data.rivers.length + 1 : state.data.roads.length + 1;
    if (draw.kind === 'river') {
      var river = {
        id: Data.nextId('river', state.data),
        name: 'Река ' + count,
        points: draw.points.slice(),
        width: 7, depth: 0.8, bankWidth: 6,
        waterHeight: state.data.terrain.waterLevel + 1,
        autoWater: true, smoothness: 0.5,
        crossSection: 'smooth_u', bankTransition: 'smoothstep', flowDirection: 'forward'
      };
      state.data.rivers.push(river);
      state.draw = null;
      scene.clearPreview();
      state.selection = { kind: 'river', id: river.id };
      structuralRebuild();
      toast('Река создана. Точки можно тянуть маркерами.', 'ok');
    } else {
      var road = {
        id: Data.nextId('road', state.data),
        name: 'Дорога ' + count,
        points: draw.points.slice(),
        width: 7, type: 'dirt', smoothness: 0.5
      };
      state.data.roads.push(road);
      state.draw = null;
      scene.clearPreview();
      state.selection = { kind: 'road', id: road.id };
      structuralRebuild();
      toast('Дорога создана.', 'ok');
    }
    updateDrawHud();
    updateToolUI();
  }

  function cancelDraw() {
    state.draw = null;
    scene.clearPreview();
    updateDrawHud();
    toast('Рисование отменено', 'warn');
  }

  function startZoneDrag(e) {
    var t = terrainAt(e);
    if (!t) return;
    state.drag = { mode: 'zoneCreate', start: { x: t.x, z: t.z }, pointerId: e.pointerId };
    canvas.setPointerCapture(e.pointerId);
    e.preventDefault();
  }

  function finishZoneDrag(e) {
    if (!state.drag) return;
    var start = state.drag.start;
    var t = terrainAt(e) || start;
    var w = Math.abs(t.x - start.x);
    var h = Math.abs(t.z - start.z);
    var cx = (start.x + t.x) / 2;
    var cz = (start.z + t.z) / 2;
    if (w < 35 || h < 35) {
      w = 150; h = 120;
      cx = start.x; cz = start.z;
    }
    var type = state.toolOptions.zoneType;
    var info = Data.ZONE_TYPES[type] || Data.ZONE_TYPES.custom;
    pushHistory();
    var zone = {
      id: Data.nextId(type.replace('custom', 'zone'), state.data),
      name: info.label + ' ' + (state.data.zones.length + 1),
      type: type,
      center: [cx, cz],
      size: [Math.max(20, w), Math.max(20, h)],
      density: state.toolOptions.zoneDensity,
      rotation: 0,
      points: Geo.ellipsePolygon(cx, cz, Math.max(20, w) / 2, Math.max(20, h) / 2, 28, 0)
    };
    if (type === 'lake' || type === 'swamp') {
      zone.waterLevel = state.data.terrain.waterLevel + (type === 'lake' ? 0.7 : 0.4);
    }
    state.data.zones.push(zone);
    state.selection = { kind: 'zone', id: zone.id };
    state.drag = null;
    scene.clearPreview();
    structuralRebuild();
    toast('Зона создана: ' + zone.name, 'ok');
  }

  function startBrush(e) {
    var t = terrainAt(e);
    if (!t) return;
    state.drag = { mode: 'brush', start: { x: t.x, z: t.z }, pointerId: e.pointerId };
    canvas.setPointerCapture(e.pointerId);
    scene.showBrushPreview(t.x, t.z, state.toolOptions.brushRadius, editColor(state.toolOptions.editType));
    e.preventDefault();
  }

  function finishBrush(e) {
    if (!state.drag) return;
    var t = terrainAt(e) || state.drag.start;
    var type = state.toolOptions.editType;
    var h = type === 'depression' ? 16 : (type === 'plateau' ? 22 : 18);
    pushHistory();
    var edit = {
      id: Data.nextId('edit', state.data),
      type: type,
      center: [t.x, t.z],
      radius: state.toolOptions.brushRadius,
      height: h,
      falloff: 0.55
    };
    state.data.terrain.edits.push(edit);
    state.selection = { kind: 'terrainEdit', id: edit.id };
    state.drag = null;
    scene.clearPreview();
    structuralRebuild();
    toast('Правка рельефа создана', 'ok');
  }

  function placeLandmark(e) {
    var t = terrainAt(e);
    if (!t) return;
    pushHistory();
    var type = state.toolOptions.landmarkType;
    var info = Data.LANDMARK_TYPES[type] || Data.LANDMARK_TYPES.point;
    var lm = {
      id: Data.nextId('landmark', state.data),
      name: info.label + ' ' + (state.data.landmarks.length + 1),
      type: type,
      position: [t.x, t.z],
      rotation: 0,
      scale: 1
    };
    state.data.landmarks.push(lm);
    state.selection = { kind: 'landmark', id: lm.id };
    structuralRebuild();
    toast('Объект добавлен: ' + lm.name, 'ok');
  }

  function placeVegetation(e) {
    var t = terrainAt(e);
    if (!t) return;
    pushHistory();
    var type = state.toolOptions.vegetationType;
    var info = Data.VEGETATION_TYPES[type] || Data.VEGETATION_TYPES.tree_pine;
    var v = {
      id: Data.nextId('veg', state.data),
      type: type,
      name: info.label,
      position: [t.x, t.z],
      rotation: 0,
      scale: 1
    };
    state.data.vegetation.push(v);
    state.selection = { kind: 'vegetation', id: v.id };
    structuralRebuild();
    toast('Растение добавлено', 'ok');
  }

  function regenCoast() {
    pushHistory();
    state.data.terrain.coast.points = Data.generateCoast(state.data.map.size, state.data.map.seed);
    structuralRebuild();
    toast('Береговая линия пересоздана', 'ok');
  }

  function addCoastVertex() {
    var pts = state.data.terrain.coast.points;
    var best = 0, bestLen = -1;
    for (var i = 0; i < pts.length; i++) {
      var a = pts[i], b = pts[(i + 1) % pts.length];
      var len = Math.hypot(b[0] - a[0], b[1] - a[1]);
      if (len > bestLen) { bestLen = len; best = i; }
    }
    var a2 = pts[best], b2 = pts[(best + 1) % pts.length];
    pushHistory();
    pts.splice(best + 1, 0, [(a2[0] + b2[0]) / 2, (a2[1] + b2[1]) / 2]);
    structuralRebuild();
    toast('Вершина берега добавлена', 'ok');
  }

  function addZoneVertex() {
    var z = getSelected();
    if (!z) return;
    var pts = z.points, best = 0, bestLen = -1;
    for (var i = 0; i < pts.length; i++) {
      var a = pts[i], b = pts[(i + 1) % pts.length];
      var len = Math.hypot(b[0] - a[0], b[1] - a[1]);
      if (len > bestLen) { bestLen = len; best = i; }
    }
    var a2 = pts[best], b2 = pts[(best + 1) % pts.length];
    pushHistory();
    pts.splice(best + 1, 0, [(a2[0] + b2[0]) / 2, (a2[1] + b2[1]) / 2]);
    syncZoneMeta(z);
    structuralRebuild();
    toast('Вершина зоны добавлена', 'ok');
  }

  function addLinePoint() {
    var line = getSelected();
    if (!line || !line.points) return;
    if (line.points.length >= 2) {
      var a = line.points[line.points.length - 2];
      var b = line.points[line.points.length - 1];
      var dx = b[0] - a[0], dz = b[1] - a[1];
      var len = Math.hypot(dx, dz) || 1;
      var step = Math.min(120, Math.max(30, len));
      pushHistory();
      line.points.push([b[0] + dx / len * step, b[1] + dz / len * step]);
      structuralRebuild();
      toast('Точка добавлена', 'ok');
    } else {
      pushHistory();
      line.points.push([state.data.map.size.width * 0.5, state.data.map.size.length * 0.5]);
      structuralRebuild();
    }
  }

  function removeLinePoint() {
    var line = getSelected();
    if (!line || !line.points) return;
    if (line.points.length <= 2) {
      toast('Нужно минимум две точки. Удалите объект целиком.', 'warn');
      return;
    }
    pushHistory();
    line.points.pop();
    structuralRebuild();
    toast('Последняя точка удалена', 'ok');
  }

  function reverseLine() {
    var line = getSelected();
    if (!line || !line.points) return;
    pushHistory();
    line.points.reverse();
    structuralRebuild();
    toast('Линия развёрнута', 'ok');
  }

  function handleInspectorAction(action) {
    if (action === 'focus') focusSelected();
    else if (action === 'delete') deleteSelection();
    else if (action === 'regenCoast') regenCoast();
    else if (action === 'addCoastVertex') addCoastVertex();
    else if (action === 'addVertex') addZoneVertex();
    else if (action === 'addLinePoint') addLinePoint();
    else if (action === 'removeLinePoint') removeLinePoint();
    else if (action === 'reverseLine') reverseLine();
    else if (action === 'fitView') scene.fitView();
  }

  /* export */

  function openExport() {
    runValidation();
    var exported = Data.exportData(state.data);
    var issues = state.issues;
    var s = Validator.summarize(issues);
    var html = '';
    html += '<span class="pill ' + (s.errors ? 'err' : 'ok') + '">Ошибок: ' + s.errors + '</span>';
    html += '<span class="pill ' + (s.warnings ? 'warn' : 'ok') + '">Предупреждений: ' + s.warnings + '</span>';
    html += '<span class="pill">Объектов: ' + (state.data.zones.length + state.data.rivers.length + state.data.roads.length + state.data.landmarks.length + state.data.vegetation.length) + '</span>';
    ui.exportSummary.innerHTML = html;
    if (!issues.length) {
      ui.exportIssues.innerHTML = '<div class="issues-empty">Проверки пройдены. JSON готов для игры.</div>';
    } else {
      var list = '';
      issues.forEach(function (iss, idx) {
        list += '<button class="issue ' + esc(iss.severity) + '" data-issue="' + idx + '"><span class="issue-dot"></span><span class="issue-text">' + esc(iss.message) + '</span></button>';
      });
      ui.exportIssues.innerHTML = list;
    }
    ui.exportJson.value = JSON.stringify(exported, null, 2);
    ui.exportModal.classList.add('open');
  }

  function closeExport() {
    ui.exportModal.classList.remove('open');
  }

  function downloadExport() {
    var json = ui.exportJson.value;
    var name = (state.data.map.name || 'island').replace(/[^a-zA-Z0-9а-яА-Я_\- ]+/g, '').trim() || 'island';
    var blob = new Blob([json], { type: 'application/json;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = name + '.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
    toast('JSON скачан', 'ok');
  }

  function copyExport() {
    var text = ui.exportJson.value;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () {
        toast('JSON скопирован', 'ok');
      }).catch(function () {
        ui.exportJson.select();
        document.execCommand('copy');
        toast('JSON скопирован', 'ok');
      });
    } else {
      ui.exportJson.select();
      document.execCommand('copy');
      toast('JSON скопирован', 'ok');
    }
  }

  function importFile(file) {
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var raw = JSON.parse(String(reader.result));
        if (replaceData(raw, true)) toast('Карта загружена: ' + file.name, 'ok');
      } catch (err) {
        toast('Ошибка импорта JSON: ' + err.message, 'error');
      }
    };
    reader.onerror = function () { toast('Не удалось прочитать файл', 'error'); };
    reader.readAsText(file, 'utf-8');
  }

  function resetMap() {
    if (!window.confirm('Сбросить карту к образцу Cozy Island? Текущие изменения будут потеряны.')) return;
    replaceData(Data.defaultData(), true);
    toast('Карта сброшена к образцу', 'ok');
  }

  /* toast */

  function toast(message, kind) {
    if (!ui.toast) return;
    var el = document.createElement('div');
    el.className = 'toast-item ' + (kind || '');
    el.textContent = message;
    ui.toast.appendChild(el);
    setTimeout(function () {
      el.classList.add('out');
      setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 250);
    }, 2600);
  }

  /* events */

  function bindEvents() {
    $$('#toolbar [data-tool]').forEach(function (b) {
      b.addEventListener('click', function () {
        var tool = b.getAttribute('data-tool');
        if (state.tool !== tool && state.draw) cancelDraw();
        state.tool = tool;
        updateToolUI();
      });
    });

    $('#btnUndo').addEventListener('click', undo);
    $('#btnRedo').addEventListener('click', redo);
    $('#btnFit').addEventListener('click', function () { scene.fitView(); });
    $('#btnIso').addEventListener('click', function () {
      state.view.mode = 'isometric';
      state.data.map.camera.type = 'isometric';
      scene.setViewMode('isometric', false);
      markDirty();
    });
    $('#btnTop').addEventListener('click', function () {
      state.view.mode = 'top';
      state.data.map.camera.type = 'top';
      scene.setViewMode('top', false);
      markDirty();
    });
    $('#btnSaveVersion').addEventListener('click', saveVersion);
    $('#btnReset').addEventListener('click', resetMap);
    $('#btnImport').addEventListener('click', function () { ui.fileInput.click(); });
    $('#btnExport').addEventListener('click', openExport);
    $('#btnExportClose').addEventListener('click', closeExport);
    $('#btnExportDownload').addEventListener('click', downloadExport);
    $('#btnExportCopy').addEventListener('click', copyExport);
    $('#btnFinishDraw').addEventListener('click', finishDraw);
    $('#btnCancelDraw').addEventListener('click', cancelDraw);
    $('#btnCheck').addEventListener('click', function () {
      runValidation();
      toast('Проверка завершена', 'ok');
    });

    ui.fileInput.addEventListener('change', function () {
      importFile(this.files && this.files[0]);
      this.value = '';
    });

    ui.versions.addEventListener('change', function () {
      if (this.value) loadVersion(this.value);
    });

    ui.heightScale.addEventListener('input', function () {
      state.view.heightScale = Number(this.value);
      ui.heightScaleOut.textContent = state.view.heightScale.toFixed(1);
      scene.heightScale = state.view.heightScale;
      rebuildScene();
    });

    ui.layers.addEventListener('change', function (e) {
      var key = e.target && e.target.getAttribute('data-layer');
      if (!key) return;
      state.layers[key] = e.target.checked;
      scene.setLayers(state.layers);
    });

    ui.inspector.addEventListener('click', function (e) {
      var b = e.target.closest('[data-action]');
      if (!b) return;
      handleInspectorAction(b.getAttribute('data-action'));
    });

    ui.objects.addEventListener('click', function (e) {
      var b = e.target.closest('.obj-item');
      if (!b) return;
      select(b.getAttribute('data-kind'), b.getAttribute('data-id'), false);
    });
    ui.objects.addEventListener('dblclick', function (e) {
      var b = e.target.closest('.obj-item');
      if (!b) return;
      select(b.getAttribute('data-kind'), b.getAttribute('data-id'), true);
    });

    ui.issues.addEventListener('click', function (e) {
      var b = e.target.closest('.issue');
      if (!b) return;
      issueClick(issueIndexFromEl(b));
    });
    ui.exportIssues.addEventListener('click', function (e) {
      var b = e.target.closest('.issue');
      if (!b) return;
      issueClick(issueIndexFromEl(b));
    });
    ui.issueBadge.addEventListener('click', function () {
      ui.issues.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    });

    ui.exportModal.addEventListener('click', function (e) {
      if (e.target === ui.exportModal) closeExport();
    });

    canvas.addEventListener('contextmenu', function (e) { e.preventDefault(); });

    canvas.addEventListener('pointerdown', function (e) {
      if (e.button === 1 || (e.button === 0 && e.altKey)) {
        startNav(e, e.shiftKey ? 'pan' : 'orbit');
        return;
      }
      if (e.button === 2) {
        if (state.draw) finishDraw();
        else startNav(e, 'pan');
        return;
      }
      if (e.button !== 0) return;

      var hit = scene.pickAt(e.clientX, e.clientY);
      if (hit && hit.type === 'handle') {
        beginHandleDrag(hit, e);
        return;
      }

      if (state.tool === 'select') {
        if (hit && hit.type === 'pick') select(hit.pick.kind, hit.pick.id, false);
        else select(null, null);
        return;
      }
      if (state.tool === 'coast') {
        if (hit && hit.type === 'pick' && hit.pick.kind === 'coast') {
          select('coast', 'coastline', false);
        } else {
          var t = terrainAt(e);
          if (t) {
            var ci = state.builder.coastInfo(t.x, t.z);
            if (Math.abs(ci.signed) < 30) select('coast', 'coastline', false);
          }
        }
        return;
      }
      if (state.tool === 'zone') { startZoneDrag(e); return; }
      if (state.tool === 'river' || state.tool === 'road') { addDrawPoint(e); return; }
      if (state.tool === 'terrain') { startBrush(e); return; }
      if (state.tool === 'landmark') { placeLandmark(e); return; }
      if (state.tool === 'vegetation') { placeVegetation(e); return; }
    });

    canvas.addEventListener('pointermove', function (e) {
      if (state.nav) {
        var dx = e.clientX - state.nav.lastX;
        var dy = e.clientY - state.nav.lastY;
        state.nav.lastX = e.clientX;
        state.nav.lastY = e.clientY;
        if (state.nav.mode === 'orbit') scene.orbit(dx, dy);
        else scene.pan(dx, dy);
        return;
      }
      if (state.drag && state.drag.mode === 'handle') {
        updateHandleDrag(e);
        updateCursor(e);
        return;
      }
      if (state.drag && state.drag.mode === 'zoneCreate') {
        var tz = terrainAt(e);
        if (tz) {
          var w = Math.abs(tz.x - state.drag.start.x);
          var h = Math.abs(tz.z - state.drag.start.z);
          var cx = (tz.x + state.drag.start.x) / 2;
          var cz = (tz.z + state.drag.start.z) / 2;
          scene.showBrushPreview(cx, cz, Math.max(w, h) / 2, '#7fd1ff');
          if (ui.coords) ui.coords.textContent = 'X ' + Geo.round(tz.x, 0) + '   Z ' + Geo.round(tz.z, 0) + '   Зона ' + Geo.round(w, 0) + '×' + Geo.round(h, 0);
        }
        return;
      }
      if (state.drag && state.drag.mode === 'brush') {
        var tb = terrainAt(e);
        if (tb) {
          scene.showBrushPreview(tb.x, tb.z, state.toolOptions.brushRadius, editColor(state.toolOptions.editType));
          updateCursor(e);
        }
        return;
      }
      updateCursor(e);
      if (state.draw) {
        var td = terrainAt(e);
        if (td) {
          scene.showDrawPreview(state.draw.points, { x: td.x, z: td.z }, state.draw.kind);
        }
      } else if (state.tool === 'zone' && lastCursor) {
        scene.showBrushPreview(lastCursor.x, lastCursor.z, 30, '#7fd1ff');
      }
    });

    canvas.addEventListener('pointerup', function (e) {
      if (state.nav) {
        state.nav = null;
        if (canvas.hasPointerCapture && canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
        return;
      }
      if (state.drag) {
        var mode = state.drag.mode;
        if (mode === 'zoneCreate') finishZoneDrag(e);
        else if (mode === 'brush') finishBrush(e);
        else if (mode === 'handle') {
          state.drag = null;
          rebuildScene();
          renderInspector();
          renderObjects();
          runValidation();
          markDirty();
        }
        if (canvas.hasPointerCapture && canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
      }
    });

    canvas.addEventListener('pointercancel', function (e) {
      state.nav = null;
      state.drag = null;
      if (canvas.hasPointerCapture && canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
      rebuildScene();
    });

    canvas.addEventListener('pointerleave', function () {
      if (!state.draw && !state.drag) scene.clearPreview();
    });

    canvas.addEventListener('wheel', function (e) {
      e.preventDefault();
      scene.zoom(e.deltaY > 0 ? 1.1 : 0.9);
    }, { passive: false });

    window.addEventListener('keydown', function (e) {
      var t = e.target;
      var typing = t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' || t.tagName === 'TEXTAREA' || t.isContentEditable);
      if (typing) return;
      if (e.key === 'Escape') {
        if (state.draw) cancelDraw();
        else if (state.drag) { state.drag = null; scene.clearPreview(); rebuildScene(); }
        else select(null, null);
        return;
      }
      if (e.key === 'Enter' && state.draw) {
        e.preventDefault();
        finishDraw();
        return;
      }
      if ((e.key === 'Delete' || e.key === 'Backspace') && state.selection) {
        e.preventDefault();
        deleteSelection();
        return;
      }
      if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key.toLowerCase() === 'z') {
        e.preventDefault();
        undo();
        return;
      }
      if ((e.ctrlKey || e.metaKey) && (e.key.toLowerCase() === 'y' || (e.shiftKey && e.key.toLowerCase() === 'z'))) {
        e.preventDefault();
        redo();
      }
    });

    window.addEventListener('beforeunload', function () {
      if (state.dirty) saveAutosave();
    });
  }

  function issueClick(idx) {
    var iss = state.issues[idx];
    if (!iss) return;
    if (iss.kind && iss.id) {
      var kinds = ['zone', 'river', 'road', 'landmark', 'vegetation', 'terrainEdit', 'coast'];
      if (kinds.indexOf(iss.kind) >= 0) {
        select(iss.kind, iss.id, true);
        return;
      }
    }
    if (iss.x != null && iss.z != null) {
      scene.focus(iss.x, iss.z, 180);
      toast(iss.message, iss.severity === 'error' ? 'error' : 'warn');
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})(window);
