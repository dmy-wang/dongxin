// 截图工具：用本地 Electron 加载 web/ 并截取面板（用于开发期视觉验收）
const { app, BrowserWindow } = require('electron');
const path = require('path');
const fs = require('fs');

app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const args = process.argv.slice(2).filter(a => a !== '--');
  const out = args[0] || '/tmp/dongxin.png';
  const query = args[1] || '';
  const w = Number(args[2] || 900), h = Number(args[3] || 700);
  const win = new BrowserWindow({
    width: w, height: h, show: false,
    webPreferences: { offscreen: false, contextIsolation: true, nodeIntegration: false },
  });
  const file = path.join(__dirname, '..', 'web', 'index.html');
  await win.loadURL('file://' + file + (query ? '?' + query : ''));
  await new Promise(r => setTimeout(r, 1400));
  const img = await win.webContents.capturePage();
  fs.writeFileSync(out, img.toPNG());
  console.log('shot:', out, w + 'x' + h);
  app.exit(0);
});
