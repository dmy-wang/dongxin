(function () {
"use strict";
// 简洁模式（占位）—— 由 simple-ui 实现
function mountSimple(root) {
  root.innerHTML = '<div class="simple-root"><div class="simple-amount" id="s-amount">0.00</div></div>';
  const el = root.querySelector('#s-amount');
  return { update(state) { el.textContent = state.amountText; } };
}

window.DX = Object.assign(window.DX || {}, { mountSimple });
})();
