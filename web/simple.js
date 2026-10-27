// 动薪 · 简洁模式（Web / Electron）
// 经典脚本 + IIFE：挂载到 window.DX.mountSimple，对齐 macOS 版 SimpleView。
(function () {
"use strict";

const DAY_LABELS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

// 状态：标题 + 主色（对应 macOS 版 Theme）
const PHASES = {
  earning:    { title: "计时中",   color: "#59f39e" },
  lunch:      { title: "午休",     color: "#ff9e26" },
  beforeWork: { title: "还没上班", color: "#59d9fa" },
  afterWork:  { title: "已下班",   color: "#ffc74d" },
  restDay:    { title: "休息日",   color: "#b3a8ff" },
};

const SVG_OPEN = '<svg viewBox="0 0 16 16" width="10" height="10" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">';
const ICONS = {
  // 底部行图标（对应 SF Symbols：hourglass / clock / checkmark.circle / moon.zzz）
  hourglass: SVG_OPEN + '<path d="M5 2.2h6v1.3c0 2.1-3 2.9-3 4.5s3 2.4 3 4.5v1.3H5v-1.3c0-2.1 3-2.9 3-4.5S5 5.6 5 3.5V2.2z"/></svg>',
  clock: SVG_OPEN + '<circle cx="8" cy="8" r="5.6"/><path d="M8 4.6V8l2.1 1.4"/></svg>',
  check: SVG_OPEN + '<circle cx="8" cy="8" r="5.6"/><path d="M5.4 8.2l1.7 1.7 3.5-3.7"/></svg>',
  moon: SVG_OPEN + '<path d="M13 9.2A5.4 5.4 0 016.8 3a5.4 5.4 0 106.2 6.2z"/></svg>',
};
const PHASE_ICON = {
  earning: "hourglass",
  lunch: "hourglass",
  beforeWork: "clock",
  afterWork: "check",
  restDay: "moon",
};

function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)); }
function pad2(n) { return String(n).padStart(2, "0"); }

// 相位判定，与 macOS 版一致：休息日 > 午休 > 计时中 > 还没上班/已下班
function phaseOf(state) {
  const snap = state.snap, cfg = state.config;
  if (!snap.isWorkday) return "restDay";
  if (snap.isLunchBreak) return "lunch";
  if (snap.isWithinWorkWindow) return "earning";
  const start = new Date(snap.now);
  start.setHours(cfg.startHour, cfg.startMinute, 0, 0);
  return snap.now < start ? "beforeWork" : "afterWork";
}

function startAt(cfg, now) {
  const d = new Date(now);
  d.setHours(cfg.startHour, cfg.startMinute, 0, 0);
  return d;
}

// 「明天 09:00 继续」/「周一 09:00 继续」，与 macOS 版 nextStartText 一致
function nextStartText(cfg, now) {
  for (let offset = 1; offset <= 7; offset++) {
    const d = new Date(now);
    d.setDate(d.getDate() + offset);
    const wd = d.getDay();
    if ((cfg.workweek || []).indexOf(wd) !== -1) {
      const prefix = offset === 1 ? "明天" : DAY_LABELS[wd];
      return prefix + " " + pad2(cfg.startHour) + ":" + pad2(cfg.startMinute) + " 继续";
    }
  }
  return "好好休息";
}

function mountSimple(root) {
  const E = window.DX || {};
  const fmt = E.fmt || {
    amount: function (v, p, d) { return (p || "") + Number(v).toFixed(d == null ? 2 : d); },
    clock: function () { return "00:00:00"; },
  };
  const displayPrefix = E.displayPrefix || function () { return ""; };

  root.innerHTML =
    '<div class="simple-root" data-phase="earning">' +
      '<div class="simple-status-row">' +
        '<span class="simple-pill"><i class="simple-pill-dot"></i><span class="simple-pill-text">计时中</span></span>' +
        '<span class="simple-today">今日 +</span>' +
      '</div>' +
      '<div class="simple-amount">' +
        '<span class="simple-prefix"></span>' +
        '<span class="simple-whole">0</span>' +
        '<span class="simple-decimals">.00</span>' +
      '</div>' +
      '<div class="simple-rate">' +
        '<span class="simple-rate-label">每秒</span>' +
        '<span class="simple-rate-value simple-rate-per-sec">0.0000</span>' +
        '<span class="simple-rate-sep">·</span>' +
        '<span class="simple-rate-value simple-rate-per-hour">0.0/时</span>' +
      '</div>' +
      '<div class="simple-gap"></div>' +
      '<div class="simple-progress-row">' +
        '<div class="simple-bar"><div class="simple-bar-fill"></div></div>' +
        '<span class="simple-pct">0%</span>' +
      '</div>' +
      '<div class="simple-footer">' +
        '<span class="simple-footer-icon">' + ICONS.hourglass + '</span>' +
        '<span class="simple-footer-leading">距下班 00:00:00</span>' +
        '<span class="simple-footer-trailing">周一</span>' +
      '</div>' +
    '</div>';

  const refs = {
    root: root.querySelector(".simple-root"),
    pillText: root.querySelector(".simple-pill-text"),
    prefix: root.querySelector(".simple-prefix"),
    whole: root.querySelector(".simple-whole"),
    decimals: root.querySelector(".simple-decimals"),
    perSec: root.querySelector(".simple-rate-per-sec"),
    perHour: root.querySelector(".simple-rate-per-hour"),
    barFill: root.querySelector(".simple-bar-fill"),
    pct: root.querySelector(".simple-pct"),
    footerIcon: root.querySelector(".simple-footer-icon"),
    footerLeading: root.querySelector(".simple-footer-leading"),
    footerTrailing: root.querySelector(".simple-footer-trailing"),
  };

  let current = null;        // 最近一次 state
  let phase = "";            // 最近一次相位，避免重复写 DOM
  let displayed = null;      // 缓动后的金额
  let target = 0;
  let raf = 0;
  let lastTs = 0;
  let lastFormatted = "";
  let lastPrefix = null;

  // 金额缓动：指数趋近，时间常数 220ms（对应 macOS .easeOut(duration: 0.22)）
  function step(ts) {
    const dt = lastTs ? Math.min(64, Math.max(1, ts - lastTs)) : 16;
    lastTs = ts;
    const k = 1 - Math.exp(-dt / 220);
    displayed += (target - displayed) * k;
    if (Math.abs(target - displayed) < 0.0005) displayed = target;
    paintAmount();
    if (displayed !== target) {
      raf = requestAnimationFrame(step);
    } else {
      raf = 0;
      lastTs = 0;
    }
  }

  function setTarget(value) {
    target = Math.max(0, value);
    if (displayed === null) {
      displayed = target;
      lastTs = 0;
    }
    if (!raf) raf = requestAnimationFrame(step);
  }

  function paintAmount() {
    if (!current || displayed === null) return;
    const prefix = current.prefix != null ? current.prefix : displayPrefix(current.config);
    const text = fmt.amount(displayed, prefix, 2);
    if (text === lastFormatted && prefix === lastPrefix) return;
    lastFormatted = text;
    lastPrefix = prefix;

    const dot = text.lastIndexOf(".");
    let whole = dot >= 0 ? text.slice(0, dot) : text;
    const decimals = dot >= 0 ? text.slice(dot) : "";
    if (prefix && whole.slice(0, prefix.length) === prefix) whole = whole.slice(prefix.length);

    if (refs.prefix.textContent !== prefix) refs.prefix.textContent = prefix;
    refs.prefix.classList.toggle("is-empty", !prefix);
    if (refs.whole.textContent !== whole) refs.whole.textContent = whole;
    if (refs.decimals.textContent !== decimals) refs.decimals.textContent = decimals;
  }

  function applyPhase(next) {
    if (next === phase) return;
    phase = next;
    const meta = PHASES[next] || PHASES.earning;
    refs.root.setAttribute("data-phase", next);
    refs.pillText.textContent = meta.title;
    refs.footerIcon.innerHTML = ICONS[PHASE_ICON[next]] || ICONS.hourglass;
  }

  function update(state) {
    if (!state || !state.snap || !state.config) return;
    current = state;
    const snap = state.snap, cfg = state.config;
    const phaseName = phaseOf(state);

    const prefix = state.prefix != null ? state.prefix : displayPrefix(cfg);
    // 速率行：圆点前缀与分隔符「·」视觉重复，此时省略（与 macOS ratePrefix 一致）
    const ratePrefix = prefix === "·" ? "" : prefix;
    const perSecText = fmt.amount(snap.perSecond, ratePrefix, 4);
    const perHourText = fmt.amount(snap.perHour, ratePrefix, 1) + "/时";
    if (refs.perSec.textContent !== perSecText) refs.perSec.textContent = perSecText;
    if (refs.perHour.textContent !== perHourText) refs.perHour.textContent = perHourText;

    // 细进度条 + 百分比
    const progress = clamp(Number(snap.todayProgress) || 0, 0, 1);
    refs.barFill.style.width = (progress * 100).toFixed(1) + "%";
    const pctText = (state.progressPct != null ? state.progressPct : Math.round(progress * 100)) + "%";
    if (refs.pct.textContent !== pctText) refs.pct.textContent = pctText;

    // 底部：距下班 / 距开始 / 今天已完成 / 下一次上班
    let leading = "";
    let trailing = "";
    if (phaseName === "earning" || phaseName === "lunch") {
      leading = "距下班 " + (state.remainingText || fmt.clock(snap.remainingWorkSeconds));
      trailing = snap.weekdayLabel || DAY_LABELS[snap.now.getDay()];
    } else if (phaseName === "beforeWork") {
      const start = startAt(cfg, snap.now);
      leading = "距开始 " + fmt.clock((start.getTime() - snap.now.getTime()) / 1000);
      trailing = pad2(cfg.startHour) + ":" + pad2(cfg.startMinute) + " 开始";
    } else if (phaseName === "afterWork") {
      leading = "今天已完成";
      trailing = nextStartText(cfg, snap.now);
    } else {
      leading = "今天休息";
      trailing = nextStartText(cfg, snap.now);
    }
    if (refs.footerLeading.textContent !== leading) refs.footerLeading.textContent = leading;
    if (refs.footerTrailing.textContent !== trailing) refs.footerTrailing.textContent = trailing;

    applyPhase(phaseName);

    // 金额：0.22s 缓动到目标值（无闪烁、无跳字）
    setTarget(snap.earnedToday);
    if (displayed === target) paintAmount();
  }

  return { update: update };
}

window.DX = Object.assign(window.DX || {}, { mountSimple: mountSimple });
})();
