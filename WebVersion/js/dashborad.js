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
  const tbody = document.getElementById("recordsBody");
  if (!meta || !tbody) return;

  meta.textContent = "正在加载…";
  tbody.innerHTML = "";

  try {
    const resp = await fetch(API_BASE() + "/focus?limit=500", {
      headers: { Authorization: "Bearer " + TOKEN() },
    });
    if (!resp.ok) {
      meta.textContent = `加载失败：${resp.status}`;
      return;
    }
    const list = await resp.json(); // [{id, start_time, end_time, task}, ...]
    renderRecords(list);
    meta.textContent = `共 ${list.length} 条`;
  } catch (e) {
    meta.textContent = "加载失败：" + e.message;
  }
}

function renderRecords(list) {
  const tbody = document.getElementById("recordsBody");
  if (!tbody) return;
  tbody.innerHTML = "";
  (list || []).forEach((r, i) => {
    const tr = document.createElement("tr");
    const dur = new Date(r.end_time) - new Date(r.start_time);
    tr.innerHTML = `
      <td style="padding:10px 12px; border-bottom:1px solid #f0f0f0;">${
        i + 1
      }</td>
      <td style="padding:10px 12px; border-bottom:1px solid #f0f0f0;">${fmtDate(
        r.start_time
      )}</td>
      <td style="padding:10px 12px; border-bottom:1px solid #f0f0f0;">${fmtDate(
        r.end_time
      )}</td>
      <td style="padding:10px 12px; border-bottom:1px solid #f0f0f0;">${fmtDuration(
        dur
      )}</td>
      <td style="padding:10px 12px; border-bottom:1px solid #f0f0f0;">${xss(
        r.task
      )}</td>
    `;
    tbody.appendChild(tr);
  });
}

// ========== 侧边栏 & 页面切换 ==========
window.toggleSidebar = function () {
  const sidebar = document.getElementById("sidebar");
  const expandBtn = document.querySelector(".expand-btn");
  const mainContent = document.querySelector(".main-content");
  sidebar.classList.toggle("collapsed");
  if (sidebar.classList.contains("collapsed")) {
    expandBtn.style.display = "flex";
    mainContent.style.marginLeft = "0";
  } else {
    expandBtn.style.display = "none";
    mainContent.style.marginLeft = "260px";
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
