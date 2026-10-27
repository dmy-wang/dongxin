const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('dongxin', {
  setTrayTitle: (text) => ipcRenderer.send('tray-title', text),
  resize: (width, height) => ipcRenderer.send('resize', width, height),
  hide: () => ipcRenderer.send('hide'),
  show: () => ipcRenderer.send('show'),
  quit: () => ipcRenderer.send('quit'),
  onCommand: (cb) => ipcRenderer.on('command', (_e, cmd) => cb(cmd)),
});
