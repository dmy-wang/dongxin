(function () {
"use strict";
// 设置面板（占位）—— 由 simple-ui 实现
function mountSettings(root, api) {
  root.innerHTML = '<div style="padding:24px;color:#fff">设置（占位）</div>';
  return { update() {}, open() {}, close() {} };
}

window.DX = Object.assign(window.DX || {}, { mountSettings });
})();
