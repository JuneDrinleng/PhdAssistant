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

  (list || []).forEach((r) => {
    const s = new Date(r.start_time);
    const e = new Date(r.end_time);
    const sameDay = s.toDateString() === e.toDateString();

    const startStr = shortMDHM(s);
    const endStr = sameDay ? shortHM(e) : shortMDHM(e);
    const durStr = fmtDuration(e - s); // 你现有的时长格式化

    const card = document.createElement("div");
    card.className = "record-card";
    card.innerHTML = `
      <div class="task" title="${xss(r.task)}">${xss(r.task)}</div>
      <div class="when">
        <span class="range">${startStr} <i data-lucide="arrow-right"></i> ${endStr}</span>
        <span class="dur">${durStr}</span>
      </div>
    `;
    listWrap.appendChild(card);
  });

  // 渲染图标
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

  // ✅ 更新映射：add(0), stats(1), records(2), settings(3)
  const map = { add: 0, stats: 1, records: 2, settings: 3 };

  if (pageName === "add") {
    document.getElementById("addPage").classList.add("active");
  } else if (pageName === "stats") {
    document.getElementById("statsPage").classList.add("active");
  } else if (pageName === "records") {
    document.getElementById("recordsPage").classList.add("active");
    refreshRecords(); // ✅ 进入记录页时加载
  } else if (pageName === "settings") {
    document.getElementById("settingsPage").classList.add("active");
    populateSettings();
  }

  navItems[map[pageName]].classList.add("active");
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
