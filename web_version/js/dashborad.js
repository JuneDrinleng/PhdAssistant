// dashborad.js
// ========== 基本配置 ==========
const DEFAULT_API = "https://phdapi.junedrinleng.com";

// ========== 登录态守卫 ==========
(function guard() {
  const user = JSON.parse(localStorage.getItem("currentUser") || "null");
  const token = localStorage.getItem("authToken");
  if (!user?.username || !token) {
    // 未登录，回到登录页
    location.replace("./index.html");
  }
})();

// ========== 时区信息 ==========
(function showTimezone() {
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const offset = -new Date().getTimezoneOffset() / 60;
  const tzStr = offset >= 0 ? `UTC+${offset}` : `UTC${offset}`;
  const el = document.getElementById("timezoneInfo");
  if (el) el.textContent = `当前时区: ${timezone} (${tzStr})`;
})();

// ========== 工具函数 ==========
function API_BASE() {
  // 优先使用登录时写入的 apiUrl，否则回退到默认域名
  return localStorage.getItem("apiUrl") || DEFAULT_API;
}
function TOKEN() {
  return localStorage.getItem("authToken") || "";
}
function showMessage(text, type = "success") {
  const msg = document.getElementById("message");
  if (!msg) return;
  msg.className = "message";
  msg.classList.add(type === "error" ? "error" : "success");
  msg.textContent = text;
  msg.style.display = "block";
  setTimeout(() => (msg.style.display = "none"), 3000);
}
// ========== 欢迎语填充 ==========
function populateWelcome() {
  const u = JSON.parse(localStorage.getItem("currentUser") || "{}");
  const el = document.getElementById("welcomeName");
  if (el) el.textContent = u?.username || "朋友";
}

// 开始按钮：标记已看过欢迎页，并跳到“专注”页（可改为 'add'）
document.addEventListener("DOMContentLoaded", () => {
  const btn = document.getElementById("welcomeStartBtn");
  if (btn) {
    btn.addEventListener("click", () => {
      localStorage.setItem("welcomeSeen", "1");
      switchPage("live");
    });
  }

  // 首屏：如果看过欢迎页了，直接进“专注”页；否则显示欢迎页
  if (localStorage.getItem("welcomeSeen") === "1") {
    document.getElementById("homePage")?.classList.remove("active");
    switchPage("live"); // 或 'add'
  } else {
    switchPage("home");
  }

  // 首次渲染图标
  if (window.lucide?.createIcons) lucide.createIcons();
});

// === 主题切换 ===
// 主题切换：更新 link & 本地存储（路径已用 /css/theme）
function applyTheme(name) {
  const link = document.getElementById("theme-link");
  if (link) link.href = "./css/theme/theme-" + name + ".css?v=1";
  localStorage.setItem("theme", name);
}

// 进入设置页时：高亮当前主题按钮 & 绑定点击事件（无下拉）
document.addEventListener("DOMContentLoaded", () => {
  const swWrap = document.getElementById("themeSwatches");
  const current = localStorage.getItem("theme") || "red";

  if (swWrap) {
    swWrap.querySelectorAll(".pill").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.theme === current);
      btn.addEventListener("click", () => {
        const val = btn.dataset.theme;
        applyTheme(val);
        // 切换高亮
        swWrap.querySelectorAll(".pill").forEach((b) => {
          b.classList.toggle("active", b.dataset.theme === val);
        });
      });
    });
  }

  // 首次渲染图标
  if (window.lucide?.createIcons) lucide.createIcons();
});

// ========== 提交专注时间 ==========
document.getElementById("focusForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const submitBtn = document.getElementById("submitBtn");
  submitBtn.disabled = true;
  submitBtn.textContent = "⏳ 正在发送...";

  try {
    const startTime = document.getElementById("startTime").value;
    const endTime = document.getElementById("endTime").value;
    const task = document.getElementById("task").value.trim();

    if (!startTime || !endTime || !task) {
      showMessage("请完整填写开始/结束时间与任务内容。", "error");
      return;
    }
    if (new Date(endTime) <= new Date(startTime)) {
      showMessage("结束时间必须晚于开始时间。", "error");
      return;
    }

    const payload = {
      start_time: new Date(startTime).toISOString(),
      end_time: new Date(endTime).toISOString(),
      task,
    };

    const resp = await fetch(API_BASE() + "/focus", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + TOKEN(), // ✅ 统一使用 Bearer
      },
      body: JSON.stringify(payload),
    });

    if (resp.ok) {
      showMessage("✅ 已发送！");
      // 清空输入
      document.getElementById("startTime").value = "";
      document.getElementById("endTime").value = "";
      document.getElementById("task").value = "";
    } else {
      const errText = await resp.text();
      showMessage(`❌ 发送失败：${resp.status} - ${errText}`, "error");
    }
  } catch (err) {
    showMessage(`❌ 请求错误：${err.message}`, "error");
    console.error(err);
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "🚀 发送专注计划";
  }
});
// ===== 工具：格式化 =====
function fmtDate(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  // 本地时区展示
  return d.toLocaleString();
}
function fmtDuration(ms) {
  const t = Math.max(0, ms || 0);
  const h = Math.floor(t / 3600000);
  const m = Math.floor((t % 3600000) / 60000);
  const s = Math.floor((t % 60000) / 1000);
  const parts = [];
  if (h) parts.push(h + "h");
  if (m || h) parts.push(m + "m");
  parts.push(s + "s");
  return parts.join(" ");
}
function xss(s) {
  return (s ?? "").replace(
    /[&<>"']/g,
    (m) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[
        m
      ])
  );
}

// ===== 拉取并渲染记录 =====
async function refreshRecords() {
  const meta = document.getElementById("recordsMeta");
  const listWrap = document.getElementById("recordsList"); // ← 用卡片容器
  if (!meta || !listWrap) return;

  meta.textContent = "正在加载…";
  listWrap.innerHTML = "";

  try {
    const resp = await fetch(API_BASE() + "/focus?limit=500", {
      headers: { Authorization: "Bearer " + TOKEN() },
    });
    if (!resp.ok) {
      meta.textContent = `加载失败：${resp.status}`;
      return;
    }
    const list = await resp.json();
    renderRecords(list); // ← 你已有的卡片渲染函数
    meta.textContent = `共 ${list.length} 条`;
  } catch (e) {
    meta.textContent = "加载失败：" + e.message;
  }
}
// 简单的全局缓存：id -> 记录对象（供编辑时拿到原 start/end）
window._focusCache = new Map();

// 小提示（可用你已有的 toast 节点）
function showToast(text, isError = false) {
  const el = document.getElementById("toast");
  if (!el) {
    alert(text);
    return;
  }
  el.textContent = text;
  el.classList.toggle("error", !!isError);
  el.style.display = "block";
  clearTimeout(el._t);
  el._t = setTimeout(() => (el.style.display = "none"), 1800);
}

// 右键菜单：在卡片上弹出
function onRecordContextMenu(e) {
  e.preventDefault();
  const card = e.currentTarget;
  const id = card.dataset.id;
  const menu = document.getElementById("recordContextMenu");
  if (!menu) return;

  menu.dataset.recordId = id;
  menu.style.display = "block";

  // 放在鼠标附近，并避免溢出视口
  const { clientWidth: vw, clientHeight: vh } = document.documentElement;
  let x = e.clientX,
    y = e.clientY;
  // 先渲染一次再取尺寸
  const rect = menu.getBoundingClientRect();
  if (x + rect.width > vw) x = Math.max(0, vw - rect.width - 8);
  if (y + rect.height > vh) y = Math.max(0, vh - rect.height - 8);
  menu.style.left = x + "px";
  menu.style.top = y + "px";
}

function hideRecordContextMenu() {
  const menu = document.getElementById("recordContextMenu");
  if (menu) menu.style.display = "none";
}

// 点击页面其他区域、滚动、缩放时关闭菜单
document.addEventListener("click", (e) => {
  const menu = document.getElementById("recordContextMenu");
  if (!menu) return;
  if (menu.style.display === "block" && !menu.contains(e.target)) {
    hideRecordContextMenu();
  }
});
window.addEventListener("scroll", hideRecordContextMenu, true);
window.addEventListener("resize", hideRecordContextMenu);
document.addEventListener("contextmenu", (e) => {
  if (!e.target.closest(".record-card")) hideRecordContextMenu();
});

// 处理菜单点击：编辑 / 删除
document
  .getElementById("recordContextMenu")
  ?.addEventListener("click", async (e) => {
    const btn = e.target.closest(".ctx-item");
    if (!btn) return;

    const action = btn.dataset.action;
    const menu = document.getElementById("recordContextMenu");
    const id = menu.dataset.recordId;
    const rec =
      window._focusCache.get(Number(id)) || window._focusCache.get(id);
    hideRecordContextMenu();
    if (!rec) return;

    if (action === "edit") {
      // 仅修改 task；PUT 接口要求 start_time / end_time / task 都提供
      // 我们把原 start/end 回填，保证通过校验
      const def = rec.task || "";
      const val = prompt("修改专注内容：", def);
      if (val == null) return; // 取消
      const payload = {
        start_time: new Date(rec.start_time).toISOString(),
        end_time: new Date(rec.end_time).toISOString(),
        task: val.trim(),
      };
      try {
        const resp = await fetch(API_BASE() + "/focus/" + rec.id, {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer " + TOKEN(),
          },
          body: JSON.stringify(payload),
        });
        if (resp.ok) {
          showToast("已更新");
          refreshRecords();
        } else {
          const text = await resp.text();
          showToast("更新失败：" + resp.status + " " + text, true);
        }
      } catch (err) {
        showToast("请求出错：" + err.message, true);
      }
    }

    if (action === "delete") {
      if (!confirm("确认删除这条专注记录？此操作不可撤销。")) return;
      try {
        const resp = await fetch(API_BASE() + "/focus/" + rec.id, {
          method: "DELETE",
          headers: { Authorization: "Bearer " + TOKEN() },
        });
        if (resp.ok) {
          showToast("已删除");
          refreshRecords();
        } else {
          const text = await resp.text();
          showToast("删除失败：" + resp.status + " " + text, true);
        }
      } catch (err) {
        showToast("请求出错：" + err.message, true);
      }
    }
  });

function shortHM(d) {
  const mm = String(d.getMinutes()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  return `${hh}:${mm}`;
}
function shortMDHM(d) {
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${m}/${day} ${shortHM(d)}`;
}

function renderRecords(list) {
  const listWrap = document.getElementById("recordsList");
  const empty = document.getElementById("recordsEmpty");
  if (!listWrap) return;

  listWrap.innerHTML = "";
  if (!list || list.length === 0) {
    if (empty) empty.style.display = "flex";
    return;
  } else {
    if (empty) empty.style.display = "none";
  }

  window._focusCache = new Map(); // 先清空再填

  (list || []).forEach((r) => {
    const s = new Date(r.start_time);
    const e = new Date(r.end_time);
    const sameDay = s.toDateString() === e.toDateString();

    const startStr = shortMDHM(s);
    const endStr = sameDay ? shortHM(e) : shortMDHM(e);
    const durStr = fmtDuration(e - s);

    const card = document.createElement("div");
    card.className = "record-card";
    card.dataset.id = r.id; // ✅ 记录 id
    card.innerHTML = `
      <div class="task" title="${xss(r.task)}">${xss(r.task)}</div>
      <div class="when">
        <span class="range">${startStr} <i data-lucide="arrow-right"></i> ${endStr}</span>
        <span class="dur">${durStr}</span>
      </div>
    `;
    card.addEventListener("contextmenu", onRecordContextMenu); // ✅ 右键菜单
    listWrap.appendChild(card);

    window._focusCache.set(r.id, r); // ✅ 缓存记录对象
  });

  if (window.lucide?.createIcons) lucide.createIcons();
}

// ========== 侧边栏 & 页面切换 ==========
// 覆盖式展开/收起侧边栏，不再改 main-content 的 margin
window.toggleSidebar = function () {
  const sidebar = document.getElementById("sidebar");
  const expandBtn = document.querySelector(".expand-btn");
  const backdrop = document.getElementById("backdrop");

  const willOpen = sidebar.classList.contains("collapsed"); // 目前收起 → 准备打开
  if (willOpen) {
    sidebar.classList.remove("collapsed");
    expandBtn.style.display = "none";
    backdrop?.classList.add("show");
    document.body.classList.add("sidebar-open");
  } else {
    sidebar.classList.add("collapsed");
    expandBtn.style.display = "flex";
    backdrop?.classList.remove("show");
    document.body.classList.remove("sidebar-open");
  }
};

window.switchPage = function (pageName) {
  const pages = document.querySelectorAll(".page");
  const navItems = document.querySelectorAll(".nav-item");
  pages.forEach((p) => p.classList.remove("active"));
  navItems.forEach((n) => n.classList.remove("active"));

  // 侧栏顺序：live, add, stats, records, settings
  const map = { live: 0, add: 1, stats: 2, records: 3, settings: 4 };

  if (pageName === "home") {
    document.getElementById("homePage")?.classList.add("active");
    populateWelcome();
    return; // 没有侧栏高亮
  }
  if (pageName === "live") {
    document.getElementById("livePage")?.classList.add("active");
    initLiveFocusUI?.();
  } else if (pageName === "add") {
    document.getElementById("addPage")?.classList.add("active");
  } else if (pageName === "stats") {
    document.getElementById("statsPage")?.classList.add("active");
    if (window.updateStats) updateStats(window.currentScope || "week");
  } else if (pageName === "records") {
    document.getElementById("recordsPage")?.classList.add("active");
    refreshRecords?.();
  } else if (pageName === "settings") {
    document.getElementById("settingsPage")?.classList.add("active");
    populateSettings?.();
  } else {
    // 兜底回首页
    document.getElementById("homePage")?.classList.add("active");
    populateWelcome();
    return;
  }
  navItems[map[pageName]]?.classList.add("active");
};

// ========== 设置页填充（仅用户名） ==========
function populateSettings() {
  const user = JSON.parse(localStorage.getItem("currentUser") || "{}");
  document.getElementById("infoUsername").value = user.username || "未登录";
}
document.addEventListener("DOMContentLoaded", populateSettings);

// ========== 退出登录 ==========
window.logout = function () {
  // 不再涉及 apiKey
  ["currentUser", "authToken", "apiUrl"].forEach((k) =>
    localStorage.removeItem(k)
  );
  location.replace("./index.html");
};
