// 截图工具：用本地 Electron 加载 web/ 并截取（开发期视觉验收）
const { app, BrowserWindow } = require('electron');
const path = require('path');
const fs = require('fs');

app.disableHardwareAcceleration();
const os = require('os');
const tmpUserData = fs.mkdtempSync(path.join(os.tmpdir(), 'dongxin-'));
app.setPath('userData', tmpUserData);
app.setPath('sessionData', tmpUserData);
app.commandLine.appendSwitch('disable-gpu');
app.commandLine.appendSwitch('no-sandbox');
const log = (...a) => console.error('[shotter]', ...a);

function timeout(ms, name) {
  return new Promise((_, rej) => setTimeout(() => rej(new Error('timeout:' + name)), ms));
}

app.whenReady().then(async () => {
  const out = process.env.SHOT_OUT || '/tmp/dongxin.png';
  const query = process.env.SHOT_QUERY || '';
  const w = Number(process.env.SHOT_W || 900), h = Number(process.env.SHOT_H || 700);
  try {
    const win = new BrowserWindow({
      width: w, height: h, show: false, backgroundColor: '#0b0c11',
      webPreferences: { contextIsolation: true, nodeIntegration: false },
    });
    win.webContents.on('console-message', (_e, lvl, msg) => log('console:', msg));
    win.webContents.on('did-fail-load', (_e, code, desc, url) => log('FAIL', code, desc, url));
    const file = path.join(__dirname, '..', '..', 'web', 'index.html');
    const queryObj = {};
    if (query) for (const kv of query.split('&')) { const [k, v] = kv.split('='); queryObj[k] = v; }
    await Promise.race([win.loadFile(file, { query: queryObj }), timeout(15000, 'load')]);
    log('loaded');
    await new Promise(r => setTimeout(r, 1500));
    const img = await Promise.race([win.webContents.capturePage(), timeout(10000, 'capture')]);
    fs.writeFileSync(out, img.toPNG());
    console.log('shot:', out, w + 'x' + h, img.getSize());
    app.exit(0);
  } catch (e) {
    log('ERROR', e && e.message);
    app.exit(2);
  }
});
