// 把仓库根目录的 web/ 同步到 desktop/web/，供 electron-builder 打包
const fs = require('fs');
const path = require('path');
const src = path.join(__dirname, '..', 'web');
const dst = path.join(__dirname, 'web');
fs.rmSync(dst, { recursive: true, force: true });
fs.cpSync(src, dst, { recursive: true });
console.log('synced web/ -> desktop/web/');
