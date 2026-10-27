// 动薪 · 设置面板（Web / Electron）
// 经典脚本 + IIFE：挂载到 window.DX.mountSettings，对齐 macOS 版 SettingsView（520 × 660）。
// 所有控件直接调用 api.patchConfig(...)，即时保存并生效。
(function () {
"use strict";

const DAY_LABELS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
const WEEK_ORDER = [1, 2, 3, 4, 5, 6, 0];

function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)); }
function pad2(n) { return String(n).padStart(2, "0"); }

const svgWrap = (inner) =>
  '<svg class="st-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" ' +
  'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + "</svg>";

const ICONS = {
  banknote: svgWrap('<rect x="1.6" y="4" width="12.8" height="8" rx="1.6"/><circle cx="8" cy="8" r="2.1"/>'),
  clock: svgWrap('<circle cx="8" cy="8" r="5.8"/><path d="M8 4.6V8l2.2 1.4"/>'),
  calendar: svgWrap('<rect x="2" y="3.2" width="12" height="10.8" rx="1.6"/><path d="M2 6.4h12M5.4 1.6v3M10.6 1.6v3"/>'),
  sparkles: svgWrap('<path d="M8 1.8l1.3 3.1 3.1 1.3-3.1 1.3L8 10.6 6.7 7.5 3.6 6.2l3.1-1.3z"/><path d="M12.5 10.5l.5 1.2 1.2.5-1.2.5-.5 1.2-.5-1.2-1.2-.5 1.2-.5z"/>'),
  eye: svgWrap('<path d="M1.8 8S3.9 3.8 8 3.8 14.2 8 14.2 8 12.1 12.2 8 12.2 1.8 8 1.8 8z"/><circle cx="8" cy="8" r="1.7"/><path d="M2.4 2.4l11.2 11.2"/>'),
  chart: svgWrap('<path d="M2.2 2.4v11.2h11.6"/><path d="M4.6 10.6l2.6-3.1 2.5 2.1 3-4.5"/>'),
  gear: svgWrap('<circle cx="8" cy="8" r="2.4"/><path d="M8 1.4v1.9M8 12.7v1.9M1.4 8h1.9M12.7 8h1.9M4.2 3.8l1.4 1.4M10.4 10.8l1.4 1.4M12 3.8l-1.4 1.4M5.6 10.8l-1.4 1.4"/>'),
  lock: svgWrap('<rect x="3.4" y="6.8" width="9.2" height="6.6" rx="1.6"/><path d="M5.6 6.8V5.2a2.4 2.4 0 014.8 0v1.6"/>'),
  timer: svgWrap('<circle cx="8" cy="9" r="4.6"/><path d="M8 6.6V9l1.6.9M6.2 2.2h3.6M8 2.2v2.2"/>'),
  warn: svgWrap('<path d="M8 2.4 14 13.2H2z"/><path d="M8 6.4v3.1M8 11.4v.1"/>'),
  reset: svgWrap('<path d="M3 8a5 5 0 1 0 1.6-3.7"/><path d="M3.2 2.2v2.9h2.9"/>'),
  undo: svgWrap('<path d="M13 8a5 5 0 1 1-1.6-3.7"/><path d="M12.8 2.2v2.9h-2.9"/>'),
  xcircle: svgWrap('<circle cx="8" cy="8" r="5.8"/><path d="M5.9 5.9l4.2 4.2M10.1 5.9l-4.2 4.2"/>'),
  checkseal: svgWrap('<circle cx="8" cy="8" r="5.8"/><path d="M5.3 8.2l1.8 1.8 3.6-3.9"/>'),
  close: svgWrap('<path d="M4.2 4.2l7.6 7.6M11.8 4.2l-7.6 7.6"/>'),
  bolt: '<svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M9.2 1.1 3.3 9h3.4l-.9 5.9L12.7 7H9.3l1-5.9z"/></svg>',
};

function hourOptions() {
  let s = "";
  for (let h = 0; h < 24; h++) s += '<option value="' + h + '">' + pad2(h) + "</option>";
  return s;
}
function minuteOptions() {
  let s = "";
  for (let m = 0; m < 60; m++) s += '<option value="' + m + '">' + pad2(m) + "</option>";
  return s;
}
const HOUR_OPTS = hourOptions();
const MINUTE_OPTS = minuteOptions();

function card(iconName, title, body) {
  return '<section class="st-card">' +
    '<div class="st-card-head">' + ICONS[iconName] + "<span>" + title + "</span></div>" +
    '<div class="st-card-body">' + body + "</div>" +
    "</section>";
}

function seg(field, cls, options) {
  return '<div class="st-seg ' + cls + '" data-seg="' + field + '">' +
    options.map(function (o) {
      return '<button type="button" data-value="' + o[0] + '">' + o[1] + "</button>";
    }).join("") +
    "</div>";
}

function stepper(field, min, max, by) {
  return '<div class="st-stepper" data-step="' + field + '" data-min="' + min +
    '" data-max="' + max + '" data-by="' + by + '">' +
    '<button type="button" data-dir="1" aria-label="增加"></button>' +
    '<button type="button" data-dir="-1" aria-label="减少"></button>' +
    "</div>";
}

function toggleRow(label, field) {
  return '<label class="st-toggle"><span class="st-toggle-label">' + label + "</span>" +
    '<input type="checkbox" data-bool="' + field + '"><span class="st-switch"></span></label>';
}

function timeField(label, hourKey, minuteKey) {
  return '<div class="st-time-group">' +
    '<span class="st-time-label">' + label + "</span>" +
    '<span class="st-time-box"><select data-time="' + hourKey + '">' + HOUR_OPTS + "</select></span>" +
    '<span class="st-colon">:</span>' +
    '<span class="st-time-box"><select data-time="' + minuteKey + '">' + MINUTE_OPTS + "</select></span>" +
    "</div>";
}

function metric(label, ref) {
  return '<div class="st-metric"><span class="st-metric-label">' + label + "</span>" +
    '<span class="st-metric-value" data-ref="' + ref + '"></span></div>';
}

function daysText(value) {
  const r = Math.round((Number(value) || 0) * 100) / 100;
  if (Math.abs(r - Math.round(r)) < 0.001) return Math.round(r) + " 天";
  return r.toFixed(2) + " 天";
}

function previewPhase(cfg, snap) {
  if (!snap.isWorkday) return { label: "休息日", color: "#b3a8ff" };
  if (snap.isLunchBreak) return { label: "午休中", color: "#ff9e26" };
  if (snap.isWithinWorkWindow) return { label: "计时中", color: "#59f39e" };
  const start = new Date(snap.now);
  start.setHours(cfg.startHour, cfg.startMinute, 0, 0);
  return snap.now < start
    ? { label: "还没上班", color: "#59d9fa" }
    : { label: "已下班", color: "#ffc74d" };
}

function mountSettings(root, api) {
  const E = window.DX || {};
  const fmt = E.fmt || {
    amount: function (v, p, d) { return (p || "") + Number(v).toFixed(d == null ? 2 : d); },
    clock: function () { return "00:00:00"; },
  };
  const displayPrefix = E.displayPrefix || function () { return ""; };
  const DEFAULTS = E.DEFAULTS || {};

  const params = new URLSearchParams(location.search);
  let demoNow = null;
  if (params.get("now")) {
    const hm = params.get("now").split(":").map(Number);
    demoNow = new Date();
    demoNow.setHours(hm[0] || 0, hm[1] || 0, 0, 0);
  }
  const isDemo = params.get("settings") === "1";
  const nowFn = function () { return demoNow || new Date(); };

  // ── DOM ──────────────────────────────────────────────────────────────────
  root.innerHTML =
    '<div class="st">' +
      '<header class="st-header">' +
        '<div class="st-logo">' + ICONS.bolt + "</div>" +
        '<div class="st-heading">' +
          '<div class="st-title">偏好设置</div>' +
          '<div class="st-sub">修改即时保存并生效</div>' +
        "</div>" +
        '<button type="button" class="st-close" data-action="close" aria-label="关闭窗口">' + ICONS.close + "</button>" +
      "</header>" +
      '<div class="st-scroll">' +

        card("banknote", "薪资",
          '<div class="st-row">' +
            '<span class="st-label">月薪</span>' +
            '<span class="st-grow"></span>' +
            '<span class="st-field">' +
              '<span class="st-prefix" data-ref="prefix"></span>' +
              '<input class="st-input st-input-num" type="number" inputmode="numeric" ' +
                'data-num="monthlySalary" min="3000" max="200000" step="100" />' +
            "</span>" +
          "</div>" +
          '<div class="st-slider-block">' +
            '<input class="st-range" type="range" data-range="monthlySalary" min="3000" max="200000" step="500" />' +
            '<div class="st-range-labels"><span>3,000</span><span>200,000</span></div>' +
          "</div>" +
          '<div class="st-row">' +
            '<span class="st-label">计薪方式</span>' +
            '<span class="st-grow"></span>' +
            seg("workdayMode", "st-seg-wide", [["manual", "手动 21.75"], ["actual", "当月实际工作日"]]) +
          "</div>" +
          '<div class="st-row" data-row="manualDays">' +
            '<span class="st-label">每月计薪天数</span>' +
            '<span class="st-grow"></span>' +
            '<span class="st-mono" data-ref="manualDays">21.75 天</span>' +
            stepper("manualWorkdays", 1, 31, 0.25) +
          "</div>" +
          '<div class="st-hint" data-row="actualHint">' + ICONS.sparkles +
            "<span>按当月实际工作日自动计算（随月份变化）</span></div>"
        ) +

        card("clock", "时间",
          '<div class="st-time-row">' +
            timeField("上班", "startHour", "startMinute") +
            timeField("下班", "endHour", "endMinute") +
          "</div>" +
          '<div class="st-time-row">' +
            timeField("午休开始", "lunchStartHour", "lunchStartMinute") +
            '<div class="st-time-group">' +
              '<span class="st-time-label">午休时长</span>' +
              '<span class="st-mono" data-ref="lunchMinutes">60 分钟</span>' +
              stepper("lunchMinutes", 0, 180, 5) +
            "</div>" +
          "</div>" +
          '<div class="st-hint" data-row="workHoursHint">' + ICONS.timer +
            '<span data-ref="workHours">每日有效工时 8.0 小时/天</span></div>' +
          '<div class="st-hint st-hint-warn" data-row="endWarn">' + ICONS.warn +
            "<span>下班时间需晚于上班时间</span></div>"
        ) +

        card("calendar", "工作日",
          '<div class="st-days">' +
            WEEK_ORDER.map(function (d) {
              return '<button type="button" class="st-day" data-day="' + d + '">' + DAY_LABELS[d] + "</button>";
            }).join("") +
          "</div>" +
          '<div class="st-hint"><span class="st-hint-em" data-ref="daysCount">已选 5 天</span>' +
            '<span class="st-hint-dim">· 未选中的日期不计薪</span></div>'
        ) +

        card("sparkles", "显示",
          '<div class="st-row">' +
            '<span class="st-label">显示模式</span>' +
            '<span class="st-grow"></span>' +
            seg("displayMode", "st-seg-narrow", [["simple", "简洁"], ["hype", "鸡血"]]) +
          "</div>" +
          '<div class="st-row" data-row="intensityRow">' +
            '<span class="st-label">鸡血强度</span>' +
            '<input class="st-range" type="range" data-range="hypeIntensity" min="0.5" max="1.6" step="0.05" />' +
            '<span class="st-mono st-mono-sm" data-ref="intensityValue">1.00×</span>' +
          "</div>" +
          '<div class="st-toggle-grid">' +
            toggleRow("菜单栏显示金额", "showTrayAmount") +
            toggleRow("启动时显示面板", "showOnLaunch") +
            toggleRow("显示励志语", "motivationalEnabled") +
            toggleRow("音效", "soundEnabled") +
          "</div>"
        ) +

        card("eye", "隐私",
          '<div class="st-row">' +
            '<span class="st-label">数字前缀</span>' +
            '<span class="st-grow"></span>' +
            seg("symbolStyle", "st-seg-privacy", [["none", "纯数字"], ["dot", "圆点 ·"], ["currency", "货币符号"]]) +
          "</div>" +
          '<div class="st-hint">' + ICONS.lock +
            "<span>公开场合建议选「纯数字」，数字不会暴露属性</span></div>" +
          '<div class="st-row" data-row="currencyRow">' +
            '<span class="st-label">货币符号</span>' +
            '<span class="st-grow"></span>' +
            '<input class="st-input st-input-currency" type="text" maxlength="2" data-text="currency" />' +
            '<span class="st-hint-inline">例如 ¥ 或 $</span>' +
          "</div>"
        ) +

        card("chart", "实时预览",
          '<div class="st-metrics">' +
            metric("每秒", "mps") + metric("每小时", "mph") +
            metric("每日", "mpd") + metric("每月", "mpm") +
          "</div>" +
          '<div class="st-preview-status">' +
            '<span class="st-status-pill" data-ref="statusPill"><i></i><span data-ref="statusText">计时中</span></span>' +
            '<span class="st-grow"></span>' +
            '<span class="st-preview-remain" data-ref="previewRemain">距下班 00:00:00</span>' +
          "</div>" +
          '<div class="st-progress">' +
            '<div class="st-progress-head"><span>今日进度</span>' +
              '<span class="st-progress-pct" data-ref="progressPct">0%</span></div>' +
            '<div class="st-bar"><div class="st-bar-fill" data-ref="progressFill"></div></div>' +
          "</div>"
        ) +

        card("gear", "操作",
          '<div class="st-btn-row">' +
            '<button type="button" class="st-btn st-btn-cyan" data-action="reset">' +
              ICONS.reset + "重置今日进度</button>" +
            '<button type="button" class="st-btn st-btn-amber" data-action="defaults">' +
              ICONS.undo + "恢复默认设置</button>" +
          "</div>" +
          '<button type="button" class="st-btn st-btn-plain" data-action="close">' +
            ICONS.xcircle + "关闭设置窗口</button>"
        ) +

      "</div>" +
      '<footer class="st-footer">' +
        '<span class="st-footer-icon">' + ICONS.checkseal + "</span>" +
        "<span>所有修改即时保存，无需确认</span>" +
        '<span class="st-footer-ver">动薪 v1.0</span>' +
      "</footer>" +
      '<div class="st-toast" data-ref="toast"></div>' +
    "</div>";

  // ── refs ─────────────────────────────────────────────────────────────────
  const $ = function (sel) { return root.querySelector(sel); };
  const refs = {
    salaryInput: $('input[data-num="monthlySalary"]'),
    salaryRange: $('input[data-range="monthlySalary"]'),
    prefix: $('[data-ref="prefix"]'),
    manualDaysRow: $('[data-row="manualDays"]'),
    manualDays: $('[data-ref="manualDays"]'),
    actualHint: $('[data-row="actualHint"]'),
    lunchMinutes: $('[data-ref="lunchMinutes"]'),
    workHours: $('[data-ref="workHours"]'),
    workHoursHint: $('[data-row="workHoursHint"]'),
    endWarn: $('[data-row="endWarn"]'),
    daysCount: $('[data-ref="daysCount"]'),
    intensityRow: $('[data-row="intensityRow"]'),
    intensityRange: $('input[data-range="hypeIntensity"]'),
    intensityValue: $('[data-ref="intensityValue"]'),
    currencyRow: $('[data-row="currencyRow"]'),
    currencyInput: $('input[data-text="currency"]'),
    mps: $('[data-ref="mps"]'),
    mph: $('[data-ref="mph"]'),
    mpd: $('[data-ref="mpd"]'),
    mpm: $('[data-ref="mpm"]'),
    statusPill: $('[data-ref="statusPill"]'),
    statusText: $('[data-ref="statusText"]'),
    previewRemain: $('[data-ref="previewRemain"]'),
    progressPct: $('[data-ref="progressPct"]'),
    progressFill: $('[data-ref="progressFill"]'),
    toast: $('[data-ref="toast"]'),
  };
  const allSegs = Array.prototype.slice.call(root.querySelectorAll("[data-seg]"));
  const allDays = Array.prototype.slice.call(root.querySelectorAll(".st-day"));
  const allToggles = Array.prototype.slice.call(root.querySelectorAll("input[data-bool]"));
  const allTimeSelects = Array.prototype.slice.call(root.querySelectorAll("select[data-time]"));

  let lastState = null;
  let toastTimer = 0;

  function setSeg(field, value) {
    allSegs.forEach(function (segEl) {
      if (segEl.dataset.seg !== field) return;
      const btns = segEl.querySelectorAll("button");
      for (let i = 0; i < btns.length; i++) {
        btns[i].classList.toggle("on", btns[i].dataset.value === value);
      }
    });
  }

  function showToast(text) {
    if (!refs.toast) return;
    refs.toast.textContent = text;
    refs.toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { refs.toast.classList.remove("show"); }, 1800);
  }

  function currentState() {
    const cfg = api.getConfig();
    const snap = E.snapshot(cfg, nowFn());
    return {
      config: cfg,
      snap: snap,
      prefix: displayPrefix(cfg),
      remainingText: fmt.clock(snap.remainingWorkSeconds),
      progressPct: Math.round(snap.todayProgress * 100),
    };
  }

  function patch(obj) {
    api.patchConfig(obj);
    sync(currentState());
  }

  // ── 同步 UI ──────────────────────────────────────────────────────────────
  function sync(state) {
    if (!state) state = currentState();
    lastState = state;
    const cfg = state.config, snap = state.snap;
    if (!cfg || !snap) return;
    const prefix = state.prefix != null ? state.prefix : displayPrefix(cfg);
    const active = document.activeElement;

    // 薪资
    if (refs.prefix) {
      refs.prefix.textContent = prefix;
      refs.prefix.classList.toggle("is-empty", !prefix);
    }
    if (refs.salaryInput && active !== refs.salaryInput) {
      const val = String(Math.round(Number(cfg.monthlySalary) || 0));
      if (refs.salaryInput.value !== val) refs.salaryInput.value = val;
    }
    if (refs.salaryRange) {
      const val = String(clamp(Number(cfg.monthlySalary) || 3000, 3000, 200000));
      if (refs.salaryRange.value !== val) refs.salaryRange.value = val;
    }
    setSeg("workdayMode", cfg.workdayMode);
    const manual = cfg.workdayMode === "manual";
    refs.manualDaysRow.classList.toggle("st-hidden", !manual);
    refs.actualHint.classList.toggle("st-hidden", manual);
    refs.manualDays.textContent = daysText(cfg.manualWorkdays);

    // 时间
    allTimeSelects.forEach(function (sel) {
      const key = sel.dataset.time;
      const val = String(cfg[key] != null ? cfg[key] : 0);
      if (sel.value !== val) sel.value = val;
    });
    refs.lunchMinutes.textContent = Number(cfg.lunchMinutes) + " 分钟";
    const endBeforeStart = cfg.endHour * 60 + cfg.endMinute <= cfg.startHour * 60 + cfg.startMinute;
    refs.workHoursHint.classList.toggle("st-hidden", endBeforeStart);
    refs.endWarn.classList.toggle("st-hidden", !endBeforeStart);
    const daily = E.dailyWorkSeconds ? E.dailyWorkSeconds(cfg) : snap.dailyWorkSeconds;
    refs.workHours.textContent = "每日有效工时 " + (daily / 3600).toFixed(1) + " 小时/天";

    // 工作日
    const ww = cfg.workweek || [];
    allDays.forEach(function (btn) {
      btn.classList.toggle("on", ww.indexOf(Number(btn.dataset.day)) !== -1);
    });
    refs.daysCount.textContent = "已选 " + ww.length + " 天";

    // 显示
    setSeg("displayMode", cfg.displayMode);
    if (refs.intensityRange) {
      const val = String(clamp(Number(cfg.hypeIntensity) || 1, 0.5, 1.6));
      if (refs.intensityRange.value !== val) refs.intensityRange.value = val;
    }
    refs.intensityValue.textContent = (Number(cfg.hypeIntensity) || 1).toFixed(2) + "×";
    refs.intensityRow.classList.toggle("is-dim", cfg.displayMode !== "hype");
    allToggles.forEach(function (input) {
      const val = !!cfg[input.dataset.bool];
      if (input.checked !== val) input.checked = val;
    });

    // 隐私
    setSeg("symbolStyle", cfg.symbolStyle);
    const isCurrency = cfg.symbolStyle === "currency";
    refs.currencyRow.classList.toggle("st-hidden", !isCurrency);
    if (refs.currencyInput && active !== refs.currencyInput) {
      const cur = cfg.currency || "";
      if (refs.currencyInput.value !== cur) refs.currencyInput.value = cur;
    }

    // 实时预览
    if (refs.mps) refs.mps.textContent = fmt.amount(snap.perSecond, prefix, 4);
    if (refs.mph) refs.mph.textContent = fmt.amount(snap.perHour, prefix, 1);
    if (refs.mpd) refs.mpd.textContent = fmt.amount(snap.perSecond * (snap.dailyWorkSeconds || 0), prefix, 0);
    if (refs.mpm) refs.mpm.textContent = fmt.amount(cfg.monthlySalary, prefix, 0);
    const ph = previewPhase(cfg, snap);
    refs.statusText.textContent = ph.label;
    refs.statusPill.style.setProperty("--pill-color", ph.color);
    refs.previewRemain.textContent = "距下班 " + (state.remainingText || fmt.clock(snap.remainingWorkSeconds));
    const pct = state.progressPct != null ? state.progressPct : Math.round(snap.todayProgress * 100);
    refs.progressPct.textContent = pct + "%";
    refs.progressFill.style.width = (clamp(Number(snap.todayProgress) || 0, 0, 1) * 100).toFixed(1) + "%";
  }

  // ── 交互 ─────────────────────────────────────────────────────────────────
  root.addEventListener("click", function (e) {
    const target = e.target;
    if (!target || !target.closest) return;

    const segBtn = target.closest("[data-seg] button");
    if (segBtn) {
      const field = segBtn.parentNode.dataset.seg;
      patch({ [field]: segBtn.dataset.value });
      return;
    }

    const dayBtn = target.closest(".st-day");
    if (dayBtn) {
      const day = Number(dayBtn.dataset.day);
      const list = (api.getConfig().workweek || []).slice();
      const i = list.indexOf(day);
      if (i >= 0) list.splice(i, 1); else list.push(day);
      list.sort(function (a, b) { return a - b; });
      patch({ workweek: list });
      return;
    }

    const stepBtn = target.closest(".st-stepper button");
    if (stepBtn) {
      const box = stepBtn.parentNode;
      const field = box.dataset.step;
      const by = Number(box.dataset.by) || 1;
      const min = Number(box.dataset.min);
      const max = Number(box.dataset.max);
      const dir = Number(stepBtn.dataset.dir);
      let v = (Number(api.getConfig()[field]) || 0) + by * dir;
      v = Math.round(v * 100) / 100;
      v = clamp(v, min, max);
      patch({ [field]: v });
      return;
    }

    const actionBtn = target.closest("[data-action]");
    if (!actionBtn) return;
    const action = actionBtn.dataset.action;
    if (action === "reset") {
      api.resetToday();
      showToast("已重置今日进度");
    } else if (action === "defaults") {
      // 契约：恢复默认直接补丁 window.DX.DEFAULTS
      api.patchConfig(window.DX && window.DX.DEFAULTS ? window.DX.DEFAULTS : DEFAULTS);
      sync(currentState());
      showToast("已恢复默认设置");
    } else if (action === "close") {
      api.close();
    }
  });

  root.addEventListener("input", function (e) {
    const el = e.target;
    if (!el || !el.dataset) return;

    if (el.dataset.range) {
      const field = el.dataset.range;
      const raw = Number(el.value);
      const value = field === "hypeIntensity" ? Math.round(raw * 100) / 100 : raw;
      patch({ [field]: value });
      return;
    }

    if (el.dataset.text === "currency") {
      const v = String(el.value || "").trim().slice(0, 2);
      if (v) api.patchConfig({ currency: v });
      return;
    }
  });

  root.addEventListener("change", function (e) {
    const el = e.target;
    if (!el || !el.dataset) return;

    if (el.dataset.bool) {
      patch({ [el.dataset.bool]: !!el.checked });
      return;
    }

    if (el.dataset.time) {
      patch({ [el.dataset.time]: Number(el.value) });
      return;
    }

    if (el.dataset.num) {
      const field = el.dataset.num;
      const min = Number(el.min || 0);
      const max = Number(el.max || Number.MAX_SAFE_INTEGER);
      let v = Number(el.value);
      if (!isFinite(v)) v = Number(api.getConfig()[field]) || min;
      v = Math.round(clamp(v, min, max));
      el.value = String(v);
      patch({ [field]: v });
      return;
    }

    if (el.dataset.text === "currency") {
      // 清空时回落到默认符号，避免出现空前缀
      if (!String(el.value || "").trim()) {
        el.value = "¥";
        api.patchConfig({ currency: "¥" });
      }
      return;
    }
  });

  // 初次渲染（隐藏状态下也能正常工作）
  sync(currentState());

  // ?settings=1 用于开发期截图：直接显示设置窗口与遮罩
  if (isDemo) {
    const overlay = document.getElementById("settings-overlay");
    if (overlay) overlay.hidden = false;
    root.hidden = false;
    sync(currentState());
    setInterval(function () { if (lastState) sync(currentState()); }, 100);

    // 开发期截图用：?settings=1&scroll=bottom 直接滚到预览 / 操作分节
    const scrollParam = params.get("scroll");
    if (scrollParam) {
      const applyScroll = function () {
        const scroller = root.querySelector(".st-scroll");
        if (!scroller) return;
        scroller.scrollTop = scrollParam === "bottom"
          ? scroller.scrollHeight
          : (Number(scrollParam) || 0);
      };
      applyScroll();
      setTimeout(applyScroll, 60);
    }
  }

  return { update: sync };
}

window.DX = Object.assign(window.DX || {}, { mountSettings: mountSettings });
})();
