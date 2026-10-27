(function () {
"use strict";

// 鸡血模式：大号金额 + 里程碑进度 + 粒子现场 + 倒计时卡片。
// 只改本文件与 hype.css；所有文案保持中性（不出现货币/工资字眼）。

var TAU = Math.PI * 2;

var GLOW_COLORS = ['#ffc74d', '#ff9e26', '#fff2cc', '#ff6b8c', '#59d9fa'];
var CONFETTI_COLORS = ['#ffc74d', '#ff6b8c', '#59d9fa', '#59f39e', '#ff9e26'];
var WARM_WHITE = '#fff2cc';

var QUOTES = [
  '每一秒，进度都在向前',
  '稳住，节奏比速度更重要',
  '今天的专注，明天会加倍还你',
  '再往前一点，就是新的一档',
  '状态在线，继续保持',
  '不急，但别停',
  '你在前进，这就够了',
  '把这一档，稳稳拿下',
  '手感正好，别浪费',
  '时间在走，你在积累',
  '专注当下，剩下的交给时间',
  '今天的你，比昨天更稳'
];

var BANNER_PHRASES = [
  '又 +10 了',
  '这一档，稳了',
  '节奏在叠加，别停',
  '状态正好，继续',
  '又往前挪了一格',
  '手感在线，保持住'
];

var MAX_EVENT_PARTICLES = 118; // 加上≤40 环境粒子，总量封顶约 158
var MAX_AMBIENT_PARTICLES = 40;

function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
function rnd(lo, hi) { return lo + Math.random() * (hi - lo); }
function pick(arr) { return arr[(Math.random() * arr.length) | 0]; }
function nowSec() { return performance.now() / 1000; }

// 稳定伪随机：同一 index 每帧得到相同偏移，环境粒子不会闪跳
function hash(seed, salt) {
  var x = Math.imul(seed, 374761393) + Math.imul(salt, 668265263) | 0;
  x = Math.imul(x ^ (x >>> 13), 1274126177) | 0;
  x ^= x >>> 16;
  return (x & 0xFFFF) / 65535;
}

function fadeAlpha(p) {
  if (p < 0.10) return p / 0.10;
  if (p > 0.62) return Math.max(0, (1 - p) / 0.38);
  return 1;
}

function mountHype(root) {
  if (!root) return { update: function () {}, destroy: function () {} };

  var N = window.DX || {};
  var fmt = N.fmt || {};

  root.innerHTML = [
    '<div class="hype-root" data-status="after" data-active="0">',
    '  <div class="hype-layer">',
    '    <div class="hype-top">',
    '      <div class="hype-pill"><span class="hype-dot"></span><span class="hype-pill-text">已下班</span></div>',
    '      <div class="hype-combo" hidden>',
    '        <span class="hype-combo-flame">🔥</span>',
    '        <span class="hype-combo-label">连击</span>',
    '        <span class="hype-combo-x">×</span>',
    '        <span class="hype-combo-n">0</span>',
    '      </div>',
    '    </div>',
    '    <div class="hype-main">',
    '      <div class="hype-amount-wrap"><div class="hype-amount">0.00</div></div>',
    '      <div class="hype-meta">',
    '        <span class="hype-meta-ps">每秒 <b class="hype-ps-val">0.0000</b></span>',
    '        <span class="hype-sep"></span>',
    '        <span class="hype-hourly">0/时</span>',
    '        <span class="hype-meta-spacer"></span>',
    '        <span class="hype-meta-next">下一档 <b class="hype-next-val">0</b></span>',
    '      </div>',
    '      <div class="hype-mbar"><span class="hype-mbar-fill"></span></div>',
    '    </div>',
    '    <div class="hype-spacer"></div>',
    '    <div class="hype-card">',
    '      <div class="hype-card-top">',
    '        <div class="hype-cd-block">',
    '          <div class="hype-label hype-cd-label">距下班</div>',
    '          <div class="hype-countdown">00:00:00</div>',
    '        </div>',
    '        <div class="hype-prog-block">',
    '          <div class="hype-label hype-prog-label">今日进度</div>',
    '          <div class="hype-pct">',
    '            <span class="hype-pct-num">0</span><span class="hype-pct-sym">%</span>',
    '            <svg class="hype-arrow" viewBox="0 0 12 12" aria-hidden="true">',
    '              <path d="M1.6 9.4 4.9 6.1l2 2L10.4 4"></path>',
    '              <path d="M7.4 4h3v3"></path>',
    '            </svg>',
    '          </div>',
    '        </div>',
    '      </div>',
    '      <div class="hype-progress">',
    '        <div class="hype-progress-fill"><span class="hype-progress-shine"></span></div>',
    '        <span class="hype-progress-knob"></span>',
    '      </div>',
    '      <div class="hype-card-foot">',
    '        <div class="hype-quote"><span class="hype-quote-text">' + QUOTES[0] + '</span></div>',
    '        <div class="hype-chip"><span class="hype-chip-star">✦</span><span class="hype-chip-text">今日 0 档</span></div>',
    '      </div>',
    '    </div>',
    '  </div>',
    '  <div class="hype-banner-wrap">',
    '    <div class="hype-banner" hidden>',
    '      <span class="hype-banner-icon">✦</span>',
    '      <span class="hype-banner-title">又 +10 了</span>',
    '      <span class="hype-banner-dot">·</span>',
    '      <span class="hype-banner-sub">累计 10 档</span>',
    '      <span class="hype-banner-spacer"></span>',
    '      <span class="hype-banner-tag">里程碑</span>',
    '    </div>',
    '  </div>',
    '  <canvas class="hype-canvas" aria-hidden="true"></canvas>',
    '</div>'
  ].join('\n');

  var box = root.querySelector('.hype-root');
  var canvas = root.querySelector('.hype-canvas');
  var ctx = canvas.getContext('2d');

  var el = {
    amount: root.querySelector('.hype-amount'),
    psVal: root.querySelector('.hype-ps-val'),
    hourly: root.querySelector('.hype-hourly'),
    nextVal: root.querySelector('.hype-next-val'),
    mbarFill: root.querySelector('.hype-mbar-fill'),
    pill: root.querySelector('.hype-pill'),
    pillText: root.querySelector('.hype-pill-text'),
    combo: root.querySelector('.hype-combo'),
    comboN: root.querySelector('.hype-combo-n'),
    cdLabel: root.querySelector('.hype-cd-label'),
    countdown: root.querySelector('.hype-countdown'),
    pctNum: root.querySelector('.hype-pct-num'),
    progress: root.querySelector('.hype-progress'),
    quote: root.querySelector('.hype-quote'),
    quoteText: root.querySelector('.hype-quote-text'),
    chipText: root.querySelector('.hype-chip-text'),
    banner: root.querySelector('.hype-banner'),
    bannerTitle: root.querySelector('.hype-banner-title'),
    bannerSub: root.querySelector('.hype-banner-sub')
  };

  function setText(node, text) {
    if (!node) return;
    if (node.textContent !== text) node.textContent = text;
  }

  // ---- 状态 ----
  var destroyed = false;
  var intensity = 1;
  var active = false;
  var soundEnabled = false;
  var motivational = true;
  var lastCoin = null;
  var lastMilestone = null;
  var lastGroup = null;

  // ---- 粒子 ----
  var particles = [];
  var fade = 0;

  // ---- 画布 ----
  var W = 0, H = 0, DPR = 1;
  var rafId = 0;
  var lastFrame = 0;
  var ro = null;

  // ---- 定时器 / 音效 ----
  var quoteTimer = 0;
  var quoteFadeTimer = 0;
  var bannerTimer = 0;
  var bannerToken = 0;
  var bannerIndex = 0;
  var audioCtx = null;

  // ======== 尺寸与主循环 ========

  function ensureSize() {
    var w = root.clientWidth;
    var h = root.clientHeight;
    if (!w || !h) return false;
    var dpr = Math.min(2, window.devicePixelRatio || 1);
    if (w === W && h === H && dpr === DPR) return true;
    W = w;
    H = h;
    DPR = dpr;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return true;
  }

  function startLoop() {
    if (destroyed || rafId) return;
    lastFrame = 0;
    rafId = requestAnimationFrame(frame);
  }

  function stopLoop() {
    if (rafId) {
      cancelAnimationFrame(rafId);
      rafId = 0;
    }
  }

  function prune(now) {
    if (!particles.length) return;
    var w = 0;
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      if (now - p.born <= p.life) particles[w++] = p;
    }
    particles.length = w;
  }

  function frame(ts) {
    if (destroyed) return;
    rafId = 0;
    if (!W || !H) return;
    if (document.hidden) { lastFrame = 0; rafId = requestAnimationFrame(frame); return; }

    var now = ts / 1000;
    var dt = lastFrame ? Math.min(0.05, Math.max(0.001, now - lastFrame)) : 0.016;
    lastFrame = now;

    var target = active ? 1 : 0;
    if (fade < target) fade = Math.min(target, fade + dt * 3.4);
    else if (fade > target) fade = Math.max(target, fade - dt * 2.1);

    prune(now);
    ctx.clearRect(0, 0, W, H);
    if (fade <= 0.01) {
      rafId = requestAnimationFrame(frame);
      return;
    }

    drawAmbient(now);
    drawParticles(now);
    rafId = requestAnimationFrame(frame);
  }

  // ======== 粒子生成 ========

  function makeParticle(kind, born, life, x, y, vx, vy, gravity, drag, size, color) {
    return {
      kind: kind, born: born, life: life, x: x, y: y, vx: vx, vy: vy,
      gravity: gravity, drag: drag, size: size, color: color,
      spin: rnd(0, TAU), spinSpeed: rnd(-9, 9)
    };
  }

  function pushParticle(p) {
    if (particles.length >= MAX_EVENT_PARTICLES) particles.shift();
    particles.push(p);
  }

  function spawnPulse(now) {
    if (!active || W < 2) return;
    var k = intensity;
    var ox = W * 0.26, oy = H * 0.30;
    var coins = Math.max(3, Math.round(6 * k));
    var i, ang, speed;
    for (i = 0; i < coins; i++) {
      ang = rnd(-Math.PI * 0.96, -Math.PI * 0.04);
      speed = rnd(64, 170) * k;
      pushParticle(makeParticle('orb', now, rnd(0.55, 1.05), ox, oy,
        Math.cos(ang) * speed, Math.sin(ang) * speed, 380, 1.1,
        rnd(2.0, 3.4) * (0.85 + 0.25 * k), pick(GLOW_COLORS)));
    }
    var sparks = Math.max(2, Math.round(4 * k));
    for (i = 0; i < sparks; i++) {
      pushParticle(makeParticle('spark', now, rnd(0.45, 0.9), ox, oy,
        rnd(-130, 130) * k, rnd(-200, -40) * k, 220, 0.9,
        rnd(1.6, 2.8), Math.random() > 0.55 ? '#59d9fa' : WARM_WHITE));
    }
  }

  function spawnMilestone(now) {
    if (!active || W < 2) return;
    var k = intensity;
    var ox = W * 0.26, oy = H * 0.30;
    var i, ang, speed;

    var coins = Math.max(8, Math.round(22 * k));
    for (i = 0; i < coins; i++) {
      ang = rnd(-Math.PI * 1.05, Math.PI * 0.05);
      speed = rnd(120, 330) * k;
      pushParticle(makeParticle('orb', now, rnd(0.9, 1.8), ox, oy,
        Math.cos(ang) * speed, Math.sin(ang) * speed, 430, 0.95,
        rnd(2.6, 5.2) * (0.85 + 0.25 * k), pick(GLOW_COLORS)));
    }

    var sparks = Math.max(5, Math.round(12 * k));
    for (i = 0; i < sparks; i++) {
      ang = rnd(-Math.PI, 0);
      speed = rnd(160, 400) * k;
      pushParticle(makeParticle('spark', now, rnd(0.55, 1.15), ox, oy,
        Math.cos(ang) * speed, Math.sin(ang) * speed, 240, 1.0,
        rnd(2.0, 3.8), pick(CONFETTI_COLORS)));
    }

    // 顶部彩带
    var ribbons = Math.max(6, Math.round(16 * k));
    for (i = 0; i < ribbons; i++) {
      pushParticle(makeParticle('confetti', now, rnd(1.5, 2.3),
        W * 0.5 + rnd(-150, 150), -8,
        rnd(-70, 70), rnd(30, 130), 250, 0.7,
        rnd(3.2, 6.4), pick(CONFETTI_COLORS)));
    }

    // 冲击环
    for (i = 0; i < 2; i++) {
      var ring = makeParticle('ring', now, 0.8, ox, oy, 0, 0, 0, 0,
        5 + i * 7, i === 0 ? WARM_WHITE : '#ffc74d');
      ring.spin = 0;
      ring.spinSpeed = 0;
      pushParticle(ring);
    }
  }

  // ======== 粒子绘制 ========

  function drawStar(x, y, outer, inner, rotation, alpha, color) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(rotation);
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    ctx.beginPath();
    for (var i = 0; i < 8; i++) {
      var r = (i % 2 === 0) ? outer : inner;
      var ang = i * Math.PI / 4 - Math.PI / 2;
      var px = Math.cos(ang) * r;
      var py = Math.sin(ang) * r;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawAmbient(now) {
    var k = intensity;
    var count = Math.min(MAX_AMBIENT_PARTICLES, Math.max(6, Math.round(26 * k)));
    var brightness = Math.min(1, 0.6 + 0.4 * k);

    for (var i = 0; i < count; i++) {
      var r1 = hash(i, 1);
      var r2 = hash(i, 2);
      var r3 = hash(i, 3);
      var speed = (0.05 + r1 * 0.08) * (0.7 + 0.3 * k);
      var cycle = (now * speed + r2) % 1;
      if (cycle < 0) cycle += 1;
      var x = W * (0.04 + r3 * 0.92) + Math.sin(now * (0.4 + r1) + r2 * 6.283) * (5 + r3 * 9);
      var y = H * (1.04 - cycle);
      var fadeInOut = Math.sin(Math.PI * cycle);
      var alpha = (0.09 + 0.34 * fadeInOut) * brightness * fade;
      var radius = (1.0 + r2 * 1.8) * (0.8 + 0.25 * k);
      var color = r1 > 0.80 ? '#59d9fa' : (r1 > 0.62 ? '#ff9e26' : '#ffc74d');

      if (r3 > 0.90) {
        drawStar(x, y, radius * 1.9, radius * 0.5, now * 0.5 + r2 * 6, alpha, color);
      } else {
        ctx.globalAlpha = alpha;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, TAU);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
  }

  function drawParticles(now) {
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      var age = now - p.born;
      if (age < 0 || age > p.life) continue;
      var progress = age / p.life;
      var alpha = fadeAlpha(progress) * fade;
      if (alpha <= 0.01) continue;

      var decay = p.drag > 0.001 ? (1 - Math.exp(-p.drag * age)) / p.drag : age;
      var x = p.x + p.vx * decay;
      var y = p.y + p.vy * decay + 0.5 * p.gravity * age * age;
      if (x < -40 || x > W + 40 || y < -40 || y > H + 50) continue;

      if (p.kind === 'orb') {
        var radius = p.size * (0.72 + 0.28 * (1 - progress));
        ctx.globalAlpha = alpha * 0.15;
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(x, y, radius * 2.2, 0, TAU);
        ctx.fill();
        ctx.globalAlpha = alpha * 0.95;
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, TAU);
        ctx.fill();
        ctx.globalAlpha = alpha * 0.62;
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(x - radius * 0.45, y - radius * 0.55, radius * 0.42, 0, TAU);
        ctx.fill();
      } else if (p.kind === 'spark') {
        var sr = p.size * (0.8 + 0.5 * (1 - progress));
        drawStar(x, y, sr * 1.9, sr * 0.5, p.spin + age * p.spinSpeed, alpha * 0.95, p.color);
      } else if (p.kind === 'confetti') {
        var cw = p.size * (1 - 0.18 * progress);
        var chh = cw * 0.55;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.spin + age * p.spinSpeed);
        ctx.globalAlpha = alpha * 0.9;
        ctx.fillStyle = p.color;
        ctx.fillRect(-cw / 2, -chh / 2, cw, chh);
        ctx.restore();
      } else if (p.kind === 'ring') {
        var rr = p.size + age * 230;
        ctx.globalAlpha = alpha * 0.5;
        ctx.strokeStyle = p.color;
        ctx.lineWidth = Math.max(0.8, (1 - progress) * 3.2);
        ctx.beginPath();
        ctx.arc(x, y, rr, 0, TAU);
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;
  }

  // ======== 金额 Q 弹 ========

  function popAmount(strong) {
    var node = el.amount;
    if (!node) return;
    node.classList.remove('is-pop', 'is-pop-strong');
    void node.offsetWidth;
    node.classList.add(strong ? 'is-pop-strong' : 'is-pop');
  }

  // ======== 里程碑横幅 ========

  function showBanner() {
    if (!el.banner) return;
    setText(el.bannerTitle, BANNER_PHRASES[bannerIndex % BANNER_PHRASES.length]);
    setText(el.bannerSub, '累计 ' + (lastGroup * 10) + ' 档');
    bannerIndex++;

    el.banner.hidden = false;
    el.banner.classList.remove('is-show');
    void el.banner.offsetWidth;
    el.banner.classList.add('is-show');

    bannerToken++;
    var token = bannerToken;
    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(function () {
      if (token !== bannerToken) return;
      el.banner.hidden = true;
      el.banner.classList.remove('is-show');
    }, 1800);
  }

  // ======== 音效（WebAudio 合成轻叮，默认关） ========

  function ensureAudio() {
    if (audioCtx) return audioCtx;
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    try { audioCtx = new AC(); } catch (e) { return null; }
    return audioCtx;
  }

  function unlockAudio() {
    if (!soundEnabled) return;
    var ac = ensureAudio();
    if (ac && ac.state === 'suspended') ac.resume().catch(function () {});
  }

  function playDing() {
    if (!soundEnabled) return;
    var ac = ensureAudio();
    if (!ac) return;
    if (ac.state === 'suspended') ac.resume().catch(function () {});
    var t = ac.currentTime + 0.01;
    var master = ac.createGain();
    master.gain.setValueAtTime(0.0001, t);
    master.gain.exponentialRampToValueAtTime(0.16, t + 0.012);
    master.gain.exponentialRampToValueAtTime(0.0001, t + 0.9);
    master.connect(ac.destination);

    var freqs = [1318.51, 1975.53, 2637.02];
    var levels = [0.55, 0.26, 0.10];
    for (var i = 0; i < freqs.length; i++) {
      var osc = ac.createOscillator();
      var gain = ac.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freqs[i], t);
      gain.gain.setValueAtTime(levels[i], t);
      osc.connect(gain);
      gain.connect(master);
      osc.start(t);
      osc.stop(t + 0.95);
    }
    setTimeout(function () {
      try { master.disconnect(); } catch (e) {}
    }, 1300);
  }

  // ======== 文案轮播 ========

  function startQuotes() {
    clearInterval(quoteTimer);
    quoteTimer = setInterval(function () {
      if (!motivational || !el.quote) return;
      el.quote.classList.add('is-out');
      clearTimeout(quoteFadeTimer);
      quoteFadeTimer = setTimeout(function () {
        if (destroyed) return;
        var index = 0;
        var current = el.quoteText.textContent;
        for (var i = 0; i < QUOTES.length; i++) {
          if (QUOTES[i] === current) { index = i; break; }
        }
        setText(el.quoteText, QUOTES[(index + 1) % QUOTES.length]);
        el.quote.classList.remove('is-out');
      }, 280);
    }, 15000);
  }

  // ======== 数值格式化 ========

  function fmtAmount(value, prefix, decimals) {
    if (typeof fmt.amount === 'function') {
      try { return fmt.amount(value, prefix || '', decimals); } catch (e) {}
    }
    return String(value == null ? 0 : value);
  }

  function fmtClock(seconds) {
    if (typeof fmt.clock === 'function') return fmt.clock(seconds);
    return '--:--:--';
  }

  function secondsUntilStart(snap, cfg) {
    var base = snap && snap.now ? new Date(snap.now) : new Date();
    var start = new Date(base.getTime());
    start.setHours(cfg.startHour == null ? 9 : cfg.startHour,
                   cfg.startMinute == null ? 0 : cfg.startMinute, 0, 0);
    var diff = (start.getTime() - base.getTime()) / 1000;
    return diff > 0 ? diff : null;
  }

  function statusOf(snap, cfg, earning) {
    if (!snap.isWorkday) return { key: 'rest', label: '休息日' };
    if (snap.isLunchBreak) return { key: 'lunch', label: '午休' };
    if (earning) return { key: 'working', label: '计时中' };
    if (secondsUntilStart(snap, cfg) !== null) return { key: 'before', label: '还没上班' };
    return { key: 'after', label: '已下班' };
  }

  // ======== 主更新（100ms 一次） ========

  function update(state) {
    if (destroyed || !state) return;
    var snap = state.snap || {};
    var cfg = state.config || {};
    var now = nowSec();

    intensity = clamp(Number(cfg.hypeIntensity) || 1, 0.5, 1.6);
    soundEnabled = !!cfg.soundEnabled;
    motivational = cfg.motivationalEnabled !== false;

    var earning = !!(snap.isWorkday && snap.isWithinWorkWindow && !snap.isLunchBreak);
    active = earning;
    var danger = earning && Number(snap.remainingWorkSeconds) < 3600;

    if (ensureSize() && !rafId) startLoop();

    // —— 金额 ——
    var amountText = state.amountText == null ? '0.00' : String(state.amountText);
    setText(el.amount, amountText);
    el.amount.classList.toggle('is-long', amountText.length > 11);
    el.amount.classList.toggle('is-xlong', amountText.length > 13);

    // —— 每秒 / 时 / 下一档 ——
    setText(el.psVal, state.perSecondText == null ? '0.0000' : state.perSecondText);
    setText(el.hourly, state.hourlyText == null ? '0/时' : state.hourlyText);
    setText(el.nextVal, fmtAmount(Number(snap.milestoneValue) || 0, state.prefix, 0));

    // —— 里程碑细条 ——
    var mProgress = clamp(Number(snap.milestoneProgress) || 0, 0, 1);
    el.mbarFill.style.width = (mProgress * 100).toFixed(2) + '%';

    // —— 状态胶囊 ——
    var status = statusOf(snap, cfg, earning);
    if (box.getAttribute('data-status') !== status.key) box.setAttribute('data-status', status.key);
    setText(el.pillText, status.label);

    // —— 连击 ——
    var combo = Number(state.combo) || 0;
    if (earning && combo > 0) {
      el.combo.hidden = false;
      setText(el.comboN, String(combo));
      el.combo.classList.toggle('tier-1', combo >= 30 && combo < 300);
      el.combo.classList.toggle('tier-2', combo >= 300);
    } else {
      el.combo.hidden = true;
    }

    // —— 倒计时 ——
    var remaining = Math.max(0, Number(snap.remainingWorkSeconds) || 0);
    var label, value;
    if (snap.isLunchBreak) {
      label = '午休中 · 下午继续';
      value = state.remainingText || fmtClock(remaining);
    } else if (earning) {
      label = danger ? '距下班 · 最后冲刺' : '距下班';
      value = state.remainingText || fmtClock(remaining);
    } else if (!snap.isWorkday) {
      label = '今天休息 · 明天再战';
      value = '—';
    } else {
      var untilStart = secondsUntilStart(snap, cfg);
      if (untilStart !== null) {
        label = '还没开始 · 距开工还有';
        value = fmtClock(untilStart);
      } else {
        label = '今日已下班 · 明天继续';
        value = state.remainingText || '00:00:00';
      }
    }
    setText(el.cdLabel, label);
    setText(el.countdown, value);
    if (box.classList.contains('is-danger') !== danger) box.classList.toggle('is-danger', danger);
    if (box.getAttribute('data-active') !== (earning ? '1' : '0')) {
      box.setAttribute('data-active', earning ? '1' : '0');
    }

    // —— 今日进度 ——
    var progress = clamp(Number(snap.todayProgress) || 0, 0, 1);
    var pct = clamp(Number(state.progressPct) || Math.round(progress * 100), 0, 100);
    setText(el.pctNum, String(pct));
    el.progress.style.setProperty('--p', (progress * 100).toFixed(2) + '%');

    // —— 今日档数 ——
    var crossed = Math.max(0, Math.floor((Number(snap.earnedToday) || 0) / 10));
    setText(el.chipText, '今日 ' + crossed + ' 档');

    // —— 励志语 ——
    if (el.quote) el.quote.hidden = !motivational;

    // —— 粒子触发 ——
    var coin = Number(state.coinPulse) || 0;
    var milestone = Number(state.milestoneCount) || 0;
    if (lastCoin === null) {
      lastCoin = coin;
      lastMilestone = milestone;
      lastGroup = Math.floor(milestone / 10);
    } else {
      if (coin !== lastCoin) {
        lastCoin = coin;
        if (earning) { popAmount(false); spawnPulse(now); }
      }
      if (milestone !== lastMilestone) {
        lastMilestone = milestone;
        if (earning) {
          popAmount(true);
          spawnMilestone(now);
        }
        var group = Math.floor(milestone / 10);
        if (earning && group > lastGroup) {
          lastGroup = group;
          showBanner();
          if (soundEnabled) playDing();
        } else if (group > lastGroup) {
          lastGroup = group;
        }
      }
    }
  }

  // ======== 生命周期 ========

  startQuotes();

  function onResize() {
    if (!ensureSize()) {
      stopLoop();
      return;
    }
    if (!rafId) startLoop();
  }

  if (window.ResizeObserver) {
    ro = new ResizeObserver(onResize);
    ro.observe(root);
  }
  window.addEventListener('resize', onResize);
  window.addEventListener('pointerdown', unlockAudio, true);
  window.addEventListener('keydown', unlockAudio, true);

  ensureSize();
  startLoop();

  function destroy() {
    destroyed = true;
    stopLoop();
    clearInterval(quoteTimer);
    clearTimeout(quoteFadeTimer);
    clearTimeout(bannerTimer);
    if (ro) { try { ro.disconnect(); } catch (e) {} ro = null; }
    window.removeEventListener('resize', onResize);
    window.removeEventListener('pointerdown', unlockAudio, true);
    window.removeEventListener('keydown', unlockAudio, true);
    if (audioCtx) {
      try { audioCtx.close(); } catch (e) {}
      audioCtx = null;
    }
    particles.length = 0;
    root.innerHTML = '';
  }

  return { update: update, destroy: destroy };
}

window.DX = Object.assign(window.DX || {}, { mountHype: mountHype });
})();
