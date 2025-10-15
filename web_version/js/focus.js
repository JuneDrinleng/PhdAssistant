// ===== 专注（开始/结束） =====
const LIVE_KEYS = { start: "liveFocusStart", task: "liveFocusTask" };
let liveTimerId = null;

function getLiveState() {
  const startISO = localStorage.getItem(LIVE_KEYS.start);
  const task = localStorage.getItem(LIVE_KEYS.task) || "";
  return {
    running: !!startISO,
    start: startISO ? new Date(startISO) : null,
    task,
  };
}
function setLiveState(start, task) {
  if (start) localStorage.setItem(LIVE_KEYS.start, start.toISOString());
  if (typeof task === "string") localStorage.setItem(LIVE_KEYS.task, task);
}
function clearLiveState() {
  localStorage.removeItem(LIVE_KEYS.start);
  localStorage.removeItem(LIVE_KEYS.task);
}

function fmtHMS(ms) {
  const t = Math.max(0, ms | 0);
  const h = String(Math.floor(t / 3600000)).padStart(2, "0");
  const m = String(Math.floor((t % 3600000) / 60000)).padStart(2, "0");
  const s = String(Math.floor((t % 60000) / 1000)).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

/* Toast：在页面顶端淡入淡出 */
function showToast(text, type = "success", ms = 1800) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.className = `toast ${type}`;
  el.textContent = text;
  el.style.display = "block";
  requestAnimationFrame(() => el.classList.add("show"));
  setTimeout(() => {
    el.classList.remove("show");
    setTimeout(() => {
      el.style.display = "none";
    }, 250);
  }, ms);
}

function initLiveFocusUI() {
  const st = getLiveState();
  const taskEl = document.getElementById("focusTaskText");
  const timerEl = document.getElementById("focusTimer");
  const btn = document.getElementById("focusToggleBtn");
  const msg = document.getElementById("focusMsg");

  if (!taskEl || !timerEl || !btn) return;

  // 清计时与提示
  if (liveTimerId) {
    clearInterval(liveTimerId);
    liveTimerId = null;
  }
  if (msg) {
    msg.style.display = "none";
  }

  // 同步 UI
  if (st.running && st.start) {
    taskEl.value = st.task || "（未命名任务）";
    taskEl.setAttribute("readonly", "readonly");
    taskEl.classList.add("task-locked");
    btn.textContent = "结束专注";

    const tick = () =>
      (timerEl.textContent = fmtHMS(Date.now() - st.start.getTime()));
    tick();
    liveTimerId = setInterval(tick, 1000);
  } else {
    taskEl.removeAttribute("readonly");
    taskEl.classList.remove("task-locked");
    if (!taskEl.value) taskEl.value = ""; // 不自动写“未设置”，让占位符可见
    timerEl.textContent = "00:00:00";
    btn.textContent = "开始专注";
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const taskEl = document.getElementById("focusTaskText");
  const btn = document.getElementById("focusToggleBtn");
  if (!btn || !taskEl) return;

  // Enter 在非运行状态下当“开始专注”
  taskEl.addEventListener("keydown", (e) => {
    const st = getLiveState();
    if (!st.running && e.key === "Enter") {
      e.preventDefault();
      btn.click();
    }
  });

  btn.addEventListener("click", async () => {
    const st = getLiveState();
    const msg = document.getElementById("focusMsg");

    if (!st.running) {
      // —— 开始：从输入框读取任务
      const task = (
        document.getElementById("focusTaskText").value || ""
      ).trim();
      if (!task) {
        // 输入框高亮一下
        taskEl.classList.add("input-error");
        setTimeout(() => taskEl.classList.remove("input-error"), 800);
        taskEl.focus();
        return;
      }
      setLiveState(new Date(), task);
      initLiveFocusUI();
    } else {
      // —— 结束：提交到后端
      const start = st.start;
      const end = new Date();
      const payload = {
        start_time: start.toISOString(),
        end_time: end.toISOString(),
        task: st.task || taskEl.value || "（未命名任务）",
      };

      try {
        const resp = await fetch(API_BASE() + "/focus", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer " + TOKEN(),
          },
          body: JSON.stringify(payload),
        });

        if (!resp.ok) {
          const errText = await resp.text();
          if (msg) {
            msg.className = "message error";
            msg.textContent = `保存失败：${resp.status} - ${errText}`;
            msg.style.display = "block";
          }
          return;
        }

        // 成功：复位 UI 与状态
        clearLiveState();
        if (liveTimerId) {
          clearInterval(liveTimerId);
          liveTimerId = null;
        }
        initLiveFocusUI();
        document.getElementById("focusTaskText").value = "";

        if (msg) {
          msg.style.display = "none";
          msg.textContent = "";
          msg.className = "message";
        }
        showToast("保存成功 ✅", "success");

        // 可选：当前在“查看记录”页时自动刷新
        // if (document.getElementById("recordsPage")?.classList.contains("active")) {
        //   refreshRecords?.();
        // }
      } catch (e) {
        if (msg) {
          msg.className = "message error";
          msg.textContent = "网络错误：" + e.message;
          msg.style.display = "block";
        }
      }
    }
  });

  // 首屏也初始化一次（如果默认显示 livePage）
  initLiveFocusUI();
});
