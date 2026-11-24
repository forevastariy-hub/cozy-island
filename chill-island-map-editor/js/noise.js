/* CHILL ISLAND MAP EDITOR - deterministic random + value noise */
(function (global) {
  'use strict';

  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function smoothstep(a, b, x) {
    if (a === b) return x < a ? 0 : 1;
    var t = clamp((x - a) / (b - a), 0, 1);
    return t * t * (3 - 2 * t);
  }
  function smootherstep(a, b, x) {
    if (a === b) return x < a ? 0 : 1;
    var t = clamp((x - a) / (b - a), 0, 1);
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  function hash2(x, y, seed) {
    var h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(seed | 0, 1442695041);
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    h ^= h >>> 16;
    return (h >>> 0) / 4294967295;
  }

  function Random(seed) {
    this.s = (seed >>> 0) || 1;
  }
  Random.prototype.next = function () {
    var t = this.s += 0x6D2B79F5;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  Random.prototype.range = function (a, b) { return a + (b - a) * this.next(); };
  Random.prototype.int = function (a, b) { return Math.floor(this.range(a, b + 1)); };
  Random.prototype.pick = function (arr) { return arr[Math.floor(this.next() * arr.length)]; };

  function Noise2D(seed) {
    this.seed = (seed | 0) || 1;
  }
  Noise2D.prototype.noise = function (x, y) {
    var xi = Math.floor(x), yi = Math.floor(y);
    var xf = x - xi, yf = y - yi;
    var u = xf * xf * (3 - 2 * xf);
    var v = yf * yf * (3 - 2 * yf);
    var a = hash2(xi, yi, this.seed);
    var b = hash2(xi + 1, yi, this.seed);
    var c = hash2(xi, yi + 1, this.seed);
    var d = hash2(xi + 1, yi + 1, this.seed);
    return lerp(lerp(a, b, u), lerp(c, d, u), v) * 2 - 1;
  };
  Noise2D.prototype.fbm = function (x, y, octaves, lacunarity, gain) {
    octaves = octaves || 5;
    lacunarity = lacunarity || 2.0;
    gain = gain || 0.5;
    var sum = 0, amp = 1, norm = 0, fx = x, fy = y;
    for (var i = 0; i < octaves; i++) {
      sum += this.noise(fx, fy) * amp;
      norm += amp;
      amp *= gain;
      fx *= lacunarity;
      fy *= lacunarity;
      fx += 17.13;
      fy -= 9.71;
    }
    return norm > 0 ? sum / norm : 0;
  };
  Noise2D.prototype.ridged = function (x, y, octaves) {
    octaves = octaves || 4;
    var sum = 0, amp = 1, norm = 0, fx = x, fy = y;
    for (var i = 0; i < octaves; i++) {
      var n = 1 - Math.abs(this.noise(fx, fy));
      n = n * n;
      sum += n * amp;
      norm += amp;
      amp *= 0.5;
      fx *= 2.03;
      fy *= 2.03;
    }
    return norm > 0 ? sum / norm : 0;
  };

  global.CHILL = global.CHILL || {};
  global.CHILL.Noise = {
    clamp: clamp,
    lerp: lerp,
    smoothstep: smoothstep,
    smootherstep: smootherstep,
    hash2: hash2,
    Random: Random,
    Noise2D: Noise2D
  };
})(window);
