const { app, BrowserWindow, Tray, Menu, nativeImage, screen, ipcMain } = require('electron');
const path = require('path');

const isDev = process.argv.includes('--dev');
let win = null;
let tray = null;
let trayTitle = '';
let mode = 'simple';

const SIZES = { simple: [348, 208], hype: [448, 322] };

function createWindow() {
  const [w, h] = SIZES.simple;
  win = new BrowserWindow({
    width: w, height: h,
    frame: false, transparent: true, resizable: false,
    hasShadow: false, skipTaskbar: true, alwaysOnTop: true,
    fullscreenable: false, maximizable: false, minimizable: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false, sandbox: true,
    },
  });
  win.setAlwaysOnTop(true, 'floating');
  win.loadFile(path.join(__dirname, 'web', 'index.html'));
  if (isDev) win.webContents.openDevTools({ mode: 'detach' });
  win.on('closed', () => { win = null; });

  // 默认放屏幕右上角
  const { workArea } = screen.getPrimaryDisplay();
  win.setPosition(Math.round(workArea.x + workArea.width - w - 36), Math.round(workArea.y + 12));
}

function createTray() {
  const iconPath = path.join(__dirname, 'web', 'assets', 'tray.png');
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
  tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon);
  tray.setToolTip('动薪 DongXin');
  rebuildTrayMenu();
  tray.on('click', () => (win && win.isVisible() ? win.hide() : showWindow()));
}

function rebuildTrayMenu() {
  const menu = Menu.buildFromTemplate([
    { label: win && win.isVisible() ? '隐藏' : '显示', click: () => (win && win.isVisible() ? win.hide() : showWindow()) },
    { type: 'separator' },
    { label: '简洁模式', type: 'radio', checked: mode === 'simple', click: () => sendCommand('mode:simple') },
    { label: '鸡血模式', type: 'radio', checked: mode === 'hype', click: () => sendCommand('mode:hype') },
    { type: 'separator' },
    { label: '设置…', click: () => { showWindow(); sendCommand('settings'); } },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ]);
  tray.setContextMenu(menu);
}

function sendCommand(cmd) {
  if (!win) return;
  win.webContents.send('command', cmd);
  if (cmd.startsWith('mode:')) mode = cmd.split(':')[1];
  rebuildTrayMenu();
}

function showWindow() {
  if (!win) createWindow();
  win.show();
  win.setAlwaysOnTop(true, 'floating');
}

app.whenReady().then(() => {
  if (process.platform === 'darwin' && app.dock) app.dock.hide();
  createWindow();
  createTray();

  ipcMain.on('tray-title', (_e, text) => {
    trayTitle = text;
    if (tray) tray.setToolTip(`动薪 ${text}`);
  });
  ipcMain.on('resize', (_e, width, height) => {
    if (!win) return;
    const b = win.getBounds();
    win.setBounds({ x: b.x, y: b.y, width, height });
  });
  ipcMain.on('hide', () => win && win.hide());
  ipcMain.on('show', () => showWindow());
  ipcMain.on('quit', () => app.quit());
});

app.on('window-all-closed', (e) => { e.preventDefault(); });
app.on('activate', () => showWindow());
