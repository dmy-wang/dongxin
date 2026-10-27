(function () {
"use strict";
// 鸡血模式（占位）—— 由 hype-ui 实现
function mountHype(root) {
  root.innerHTML = '<div class="hype-root"><div class="hype-amount" id="h-amount">0.00</div><canvas id="h-canvas"></canvas></div>';
  const el = root.querySelector('#h-amount');
  return { update(state) { el.textContent = state.amountText; }, destroy() {} };
}

window.DX = Object.assign(window.DX || {}, { mountHype });
})();
