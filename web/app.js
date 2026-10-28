// 经典脚本：依赖 engine.js / simple.js / hype.js / settings.js 先加载
(function () {
"use strict";
const E = window.DX;
const { mountSimple } = E;
const { mountHype } = E;
const { mountSettings } = E;

const isElectron = typeof window !== 'undefined' && !!window.dongxin;
if (!isElectron) document.body.classList.add('browser');

const panel = document.getElementById('panel');
const viewSimple = document.getElementById('view-simple');
const viewHype = document.getElementById('view-hype');
const overlay = document.getElementById('settings-overlay');
const settingsRoot = document.getElementById('settings-window');
const modeLabel = document.getElementById('mode-label');

let config = E.loadConfig(localStorage);

// 演示/截图用：?mode=hype&salary=15000&now=15:00（只影响本次内存，不落盘）
const params = new URLSearchParams(location.search);
let demoNow = null;
if (params.get('now')) {
  const [h, m] = params.get('now').split(':').map(Number);
  demoNow = new Date(); demoNow.setHours(h, m, 0, 0);
}
const demoSalary = params.get('salary');
if (params.get('mode') === 'hype' || params.get('mode') === 'simple') config.displayMode = params.get('mode');
if (demoSalary) config.monthlySalary = Number(demoSalary);
if (params.get('zoom')) config.zoom = Math.min(2, Math.max(0.7, Number(params.get('zoom'))));
const now = () => demoNow || new Date();
let combo = 0;
let coinPulse = 0;
let milestoneCount = 0;
let lastYuan = null;
let lastMilestone = null;
let settingsOpen = false;

const simple = mountSimple(viewSimple);
const hype = mountHype(viewHype);
const settings = mountSettings(settingsRoot, {
  getConfig: () => config,
  patchConfig(patch) { config = { ...config, ...patch }; E.saveConfig(localStorage, config); render(true); },
  resetToday() { lastYuan = null; lastMilestone = null; combo = 0; settings.update(buildState()); },
  open() { settingsOpen = true; },
  close() { settingsOpen = false; overlay.hidden = true; settingsRoot.hidden = true; },
});

function buildState() {
  const snap = E.snapshot(config, now());
  return {
    config, snap,
    prefix: E.displayPrefix(config),
    amountText: E.fmt.amount(snap.earnedToday, E.displayPrefix(config), 2),
    hourlyText: E.fmt.amount(snap.perHour, E.displayPrefix(config), 0) + '/时',
    remainingText: E.fmt.clock(snap.remainingWorkSeconds),
    progressPct: Math.round(snap.todayProgress * 100),
    perSecondText: E.fmt.amount(snap.perSecond, E.displayPrefix(config), 4),
    combo, coinPulse, milestoneCount,
    mode: config.displayMode,
  };
}

const PANEL_SIZE = { simple: [348, 208], hype: [448, 322] };
function panelZoom() { return Math.min(2, Math.max(0.7, Number(config.zoom) || 1)); }
function syncWindowSize(size) {
  if (!isElectron) return;
  const [bw, bh] = size || PANEL_SIZE[config.displayMode] || PANEL_SIZE.simple;
  const z = panelZoom();
  window.dongxin.resize(Math.round(bw * z), Math.round(bh * z));
}
function applyZoom() {
  panel.style.zoom = String(panelZoom());
}
function openSettingsUI() {
  settingsOpen = true; overlay.hidden = false; settingsRoot.hidden = false;
  syncWindowSize([560, 700]);
  settings.update(buildState());
}
function closeSettingsUI() {
  settingsOpen = false; overlay.hidden = true; settingsRoot.hidden = true;
  syncWindowSize();
}

function render(force = false) {
  const state = buildState();
  const isHype = config.displayMode === 'hype';
  panel.classList.toggle('hype', isHype);
  viewSimple.hidden = isHype;
  viewHype.hidden = !isHype;
  modeLabel.textContent = isHype ? '鸡血模式' : '简洁模式';
  if (isHype) hype.update(state); else simple.update(state);
  if (!settingsOpen && force) syncWindowSize();
  applyZoom();
  if (settingsOpen) settings.update(state);
  if (isElectron) window.dongxin.setTrayTitle(E.fmt.amount(state.snap.earnedToday, state.prefix, 2));
  if (force) document.documentElement.style.setProperty('--mode', isHype ? 'hype' : 'simple');
}

const timer = setInterval(() => {
  const snap = E.snapshot(config, now());
  const yuan = Math.floor(snap.earnedToday);
  if (lastYuan === null) lastYuan = yuan;
  if (yuan > lastYuan) { coinPulse++; }
  lastYuan = yuan;
  const ms = Math.floor(snap.earnedToday / 10);
  if (lastMilestone === null) lastMilestone = ms;
  if (ms > lastMilestone) { milestoneCount += ms - lastMilestone; lastMilestone = ms; }
  combo = (snap.isWithinWorkWindow && !snap.isLunchBreak) ? Math.min(combo + 1, 9999) : 0;
  render();
}, 100);

// 控件
document.getElementById('btn-mode').onclick = () => {
  config = { ...config, displayMode: config.displayMode === 'hype' ? 'simple' : 'hype' };
  E.saveConfig(localStorage, config); render(true);
};
document.getElementById('btn-settings').onclick = () => openSettingsUI();
document.getElementById('btn-hide').onclick = () => {
  if (isElectron) window.dongxin.hide();
  else panel.style.display = 'none';
};
overlay.onclick = () => closeSettingsUI();
function setZoom(z) {
  config = { ...config, zoom: Math.min(2, Math.max(0.7, z)) };
  E.saveConfig(localStorage, config);
  render(true);
}
window.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && (e.key === '+' || e.key === '=')) { e.preventDefault(); setZoom(panelZoom() + 0.1); return; }
  if ((e.metaKey || e.ctrlKey) && e.key === '-') { e.preventDefault(); setZoom(panelZoom() - 0.1); return; }
  if ((e.metaKey || e.ctrlKey) && e.key === '0') { e.preventDefault(); setZoom(1); return; }
  if (e.key === 'Escape' && settingsOpen) { closeSettingsUI(); }
  if ((e.metaKey || e.ctrlKey) && e.key === ',') { document.getElementById('btn-settings').click(); }
});

render(true);
if (isElectron && config.showOnLaunch) window.dongxin.show();
})();
