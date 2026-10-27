// 动薪 · 纯逻辑引擎（Web / Electron / Node 测试共用；UMD 风格，无 ES module，避免 file:// 的 CORS 限制）
const SYMBOL_STYLES = { none: '纯数字（无前缀）', dot: '圆点前缀 ·', currency: '货币符号' };

const DEFAULTS = {
  monthlySalary: 15000,
  workdayMode: 'manual',      // manual | actual
  manualWorkdays: 21.75,
  startHour: 9, startMinute: 0,
  endHour: 18, endMinute: 0,
  lunchStartHour: 12, lunchStartMinute: 0,
  lunchMinutes: 60,
  currency: '¥',
  symbolStyle: 'none',
  displayMode: 'simple',      // simple | hype
  showTrayAmount: true,
  motivationalEnabled: true,
  hypeIntensity: 1,
  soundEnabled: false,
  showOnLaunch: true,
  workweek: [1, 2, 3, 4, 5],  // JS getDay(): 0=周日 … 6=周六
};

function loadConfig(storage) {
  try {
    const raw = storage && storage.getItem('dongxin.config.v1');
    if (!raw) return { ...DEFAULTS };
    const parsed = JSON.parse(raw);
    return { ...DEFAULTS, ...parsed };
  } catch { return { ...DEFAULTS }; }
}

function saveConfig(storage, cfg) {
  try { storage && storage.setItem('dongxin.config.v1', JSON.stringify(cfg)); } catch {}
}

function displayPrefix(cfg) {
  if (cfg.symbolStyle === 'dot') return '·';
  if (cfg.symbolStyle === 'currency') return cfg.currency || '¥';
  return '';
}

function dailyWorkSeconds(cfg) {
  const total = Math.max(0, ((cfg.endHour * 60 + cfg.endMinute) - (cfg.startHour * 60 + cfg.startMinute)) * 60);
  return Math.max(60, total - (cfg.lunchMinutes || 0) * 60);
}

function workdaysPerMonth(cfg, now = new Date()) {
  if (cfg.workdayMode !== 'actual') return Math.max(1, cfg.manualWorkdays || 21.75);
  const y = now.getFullYear(), m = now.getMonth();
  const days = new Date(y, m + 1, 0).getDate();
  let count = 0;
  for (let d = 1; d <= days; d++) {
    if ((cfg.workweek || []).includes(new Date(y, m, d).getDay())) count++;
  }
  return Math.max(1, count);
}

function perSecond(cfg, now = new Date()) {
  return Math.max(0, cfg.monthlySalary || 0) / (workdaysPerMonth(cfg, now) * dailyWorkSeconds(cfg));
}

function atTime(base, h, m) {
  const d = new Date(base);
  d.setHours(h, m, 0, 0);
  return d;
}

function snapshot(cfg, now = new Date()) {
  const ps = perSecond(cfg, now);
  const weekday = now.getDay();
  const isWorkday = (cfg.workweek || []).includes(weekday);
  const DAY = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  const start = atTime(now, cfg.startHour, cfg.startMinute);
  const end = atTime(now, cfg.endHour, cfg.endMinute);
  const lunchStart = atTime(now, cfg.lunchStartHour, cfg.lunchStartMinute);
  const lunchEnd = new Date(lunchStart.getTime() + (cfg.lunchMinutes || 0) * 60000);

  const isWithinWorkWindow = now >= start && now < end;
  const isLunchBreak = isWithinWorkWindow && now >= lunchStart && now < lunchEnd;

  let worked = 0; // 秒
  if (isWorkday && now > start) {
    const cursor = Math.min(now, end);
    worked = (cursor - start) / 1000;
    if (cursor > lunchStart) {
      worked -= (Math.min(cursor, lunchEnd) - lunchStart) / 1000;
    }
    worked = Math.max(0, Math.min(worked, dailyWorkSeconds(cfg)));
  }

  let remaining = 0;
  if (isWorkday && now < end) {
    remaining = (end - Math.max(now, start)) / 1000;
    if (now < lunchStart) remaining -= (cfg.lunchMinutes || 0) * 60;
    else if (now < lunchEnd) remaining -= (lunchEnd - now) / 1000;
  }
  remaining = Math.max(0, Math.min(remaining, dailyWorkSeconds(cfg)));

  const earnedToday = ps * worked;
  const step = 10;
  const milestoneValue = Math.floor(earnedToday / step) * step + step;

  let statusText = '计时中';
  if (!isWorkday) statusText = '今天休息 · 不用上班';
  else if (now < start) statusText = '还没开始 · 距开工还有';
  else if (now >= end) statusText = '今日已下班 · 明天继续';
  else if (isLunchBreak) statusText = '午休中 · 稍后继续';

  return {
    now, perSecond: ps, perMinute: ps * 60, perHour: ps * 3600,
    earnedToday, workedSecondsToday: worked, remainingWorkSeconds: remaining,
    todayProgress: dailyWorkSeconds(cfg) > 0 ? Math.min(1, worked / dailyWorkSeconds(cfg)) : 0,
    isWorkday, isWithinWorkWindow, isLunchBreak,
    milestoneValue, milestoneProgress: (earnedToday - (milestoneValue - step)) / step,
    weekdayLabel: DAY[weekday], statusText,
    dailyWorkSeconds: dailyWorkSeconds(cfg),
  };
}

const fmt = {
  amount(value, prefix = '', decimals = 2) {
    const neg = value < 0;
    const n = Math.abs(value).toFixed(decimals);
    const [whole, frac] = n.split('.');
    const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return (neg ? '-' : '') + prefix + grouped + (decimals ? '.' + frac : '');
  },
  clock(seconds) {
    const t = Math.max(0, Math.round(seconds));
    const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60;
    return [h, m, s].map(v => String(v).padStart(2, '0')).join(':');
  },
  shortClock(seconds) {
    const t = Math.max(0, Math.round(seconds));
    const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60);
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
  },
};


(function (root) {
  const api = {
    SYMBOL_STYLES, DEFAULTS, loadConfig, saveConfig, displayPrefix,
    dailyWorkSeconds, workdaysPerMonth, perSecond, snapshot, fmt,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.DX = Object.assign(root.DX || {}, api);
})(typeof globalThis !== 'undefined' ? globalThis : window);
