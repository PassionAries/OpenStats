/* OpenStats 官网 · 页面外壳：主题切换、菜单栏下拉菜单、时钟、桌面小组件拖动、滚动淡入与拷贝 */
(() => {
  "use strict";

  const root = document.documentElement;
  const THEME_KEY = "os-theme";
  const media = window.matchMedia("(prefers-color-scheme: dark)");

  function saved() {
    try { return localStorage.getItem(THEME_KEY); } catch { return null; }
  }
  function applyTheme(theme, persist) {
    root.dataset.theme = theme;
    if (!persist) return;
    try { localStorage.setItem(THEME_KEY, theme); } catch { /* 隐私模式下不可用，忽略 */ }
  }

  applyTheme(saved() || (media.matches ? "dark" : "light"), false);
  // 没有手动选过时跟随系统
  media.addEventListener("change", (e) => { if (!saved()) applyTheme(e.matches ? "dark" : "light", false); });
  document.getElementById("themeToggle")?.addEventListener("click", (e) => {
    e.stopPropagation();
    applyTheme(root.dataset.theme === "dark" ? "light" : "dark", true);
  });

  // ── 菜单栏下拉菜单：点击展开，展开后悬停切换，点外部或 Esc 收起 ──
  const menus = [...document.querySelectorAll(".mb-menu")];
  let openMenu = null;

  function setMenu(menu) {
    for (const m of menus) {
      const open = m === menu;
      m.classList.toggle("is-open", open);
      m.querySelector(".mb-title")?.setAttribute("aria-expanded", String(open));
    }
    openMenu = menu;
  }

  for (const menu of menus) {
    const title = menu.querySelector(".mb-title");
    title?.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      setMenu(openMenu === menu ? null : menu);
    });
    menu.addEventListener("mouseenter", () => { if (openMenu && openMenu !== menu) setMenu(menu); });
    // 选中一项后收起；replica.js 在冒泡阶段先处理风格切换
    menu.querySelector(".mb-drop")?.addEventListener("click", () => setTimeout(() => setMenu(null), 0));
  }
  document.addEventListener("click", (e) => { if (openMenu && !openMenu.contains(e.target)) setMenu(null); });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") setMenu(null); });

  // ── 时钟：按访客本地时间显示 ──
  const clock = document.getElementById("menubarClock");
  const format = new Intl.DateTimeFormat("zh-CN", { month: "numeric", day: "numeric", weekday: "short", hour: "2-digit", minute: "2-digit", hour12: false });
  function renderClock() {
    if (!clock) return;
    const now = new Date();
    const parts = Object.fromEntries(format.formatToParts(now).map((p) => [p.type, p.value]));
    clock.textContent = `${parts.month}月${parts.day}日 ${parts.weekday} ${parts.hour}:${parts.minute}`;
    clock.dateTime = now.toISOString();
  }
  renderClock();
  setInterval(renderClock, 15000);

  // ── 桌面小组件：按住拖动，限制在桌面范围内；松开后记住位置（本次浏览有效） ──
  const widget = document.getElementById("widget");
  const desktop = document.getElementById("top");
  if (widget && desktop) {
    let drag = null;
    widget.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      const box = widget.getBoundingClientRect(), area = desktop.getBoundingClientRect();
      drag = { dx: e.clientX - box.left, dy: e.clientY - box.top, area, w: box.width, h: box.height };
      widget.setPointerCapture(e.pointerId);
      widget.classList.add("is-dragging");
    });
    widget.addEventListener("pointermove", (e) => {
      if (!drag) return;
      const { area, dx, dy, w, h } = drag;
      const x = Math.min(Math.max(e.clientX - area.left - dx, 8), area.width - w - 8);
      const y = Math.min(Math.max(e.clientY - area.top - dy, 38), area.height - h - 84);
      widget.style.left = `${x}px`;
      widget.style.top = `${y}px`;
      widget.style.bottom = "auto";
    });
    const end = () => { drag = null; widget.classList.remove("is-dragging"); };
    widget.addEventListener("pointerup", end);
    widget.addEventListener("pointercancel", end);
  }

  // ── 滚动进入视野时淡入 ──
  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-visible");
        io.unobserve(entry.target);
      }
    }, { rootMargin: "0px 0px -8% 0px" });
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-visible"));
  }

  // ── 拷贝按钮 ──
  document.addEventListener("click", async (e) => {
    const button = e.target.closest("[data-copy]");
    if (!button) return;
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      const text = button.textContent;
      button.textContent = "已拷贝";
      setTimeout(() => { button.textContent = text; }, 1400);
    } catch { /* 剪贴板不可用时什么也不做 */ }
  });
})();
