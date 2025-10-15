// ===== 统计页：任务占比饼图 =====
let pieChart = null;
let currentScope = "week";

// 通用时间工具（与 focus 版本一致）
function parseAny(str) {
  if (typeof str !== "string") return new Date(str);
  return str.includes("T")
    ? new Date(str)
    : new Date(str.replace(" ", "T") + "Z");
}
function diffMins(s, e) {
  return ((parseAny(e) - parseAny(s)) / 60000) | 0;
}
function makePalette(n, baseHue = 350) {
  const arr = [];
  for (let i = 0; i < n; i++) {
    const h = (baseHue + (360 / n) * i) % 360;
    arr.push(`hsl(${h}deg 55% 75%)`);
  }
  return arr;
}

// 拉取记录（可复用已有 refreshRecords 的数据，如果你愿意也可以改为直接用它的缓存）
async function loadFocusForStats(limit = 1000) {
  const resp = await fetch(API_BASE() + `/focus?limit=${limit}`, {
    headers: { Authorization: "Bearer " + TOKEN() },
  });
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  return resp.json();
}

async function updateStats(scope = "week") {
  currentScope = scope;
  const now = new Date();
  const todayStr = now.toDateString();
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
  monday.setHours(0, 0, 0, 0);

  // 数据
  const recs = await loadFocusForStats(2000);

  let totalMins = 0;
  const taskMins = {};
  const daysInRange = new Set();

  recs.forEach((r) => {
    const st = parseAny(r.start_time);
    const within =
      scope === "day"
        ? st.toDateString() === todayStr
        : scope === "week"
        ? st >= monday
        : scope === "month"
        ? st.getFullYear() === now.getFullYear() &&
          st.getMonth() === now.getMonth()
        : true;
    if (!within) return;
    const m = diffMins(r.start_time, r.end_time);
    totalMins += m;
    taskMins[r.task] = (taskMins[r.task] || 0) + m;
    daysInRange.add(st.toDateString());
  });

  const fmt = (m) => (m >= 60 ? `${(m / 60) | 0}小时${m % 60}分` : `${m}分`);
  const rangeTxt =
    scope === "day"
      ? now.toLocaleDateString()
      : scope === "week"
      ? `${monday.toLocaleDateString()} ~ ${now.toLocaleDateString()}`
      : scope === "month"
      ? now.toLocaleDateString().slice(0, 7)
      : "";

  document.getElementById("date-range").textContent = rangeTxt;
  document.getElementById("summary-line").textContent = `总计 ${fmt(
    totalMins
  )}　日均 ${
    daysInRange.size ? fmt((totalMins / daysInRange.size) | 0) : "0分"
  }`;

  const labels = Object.entries(taskMins).map(([t, m]) => `${t}  ${fmt(m)}`);
  const data = Object.values(taskMins);

  const ctx = document.getElementById("taskChart").getContext("2d");
  if (pieChart) pieChart.destroy();
  if (!data.length) {
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    document.getElementById("chart-legend").innerHTML = "";
    return;
  }

  pieChart = new Chart(ctx, {
    type: "pie",
    data: {
      labels,
      datasets: [
        {
          data,
          backgroundColor: makePalette(data.length),
          borderColor:
            getComputedStyle(document.documentElement).getPropertyValue(
              "--card-bg"
            ) || "#fff",
          borderWidth: 1,
          hoverOffset: 6,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true, // ✅ 交给 Chart.js 保持比例
      aspectRatio: 1, // ✅ 宽:高 = 1:1，保证正圆
      layout: { padding: 6 }, // 适当留白更紧凑
      radius: "90%", // 再缩一点，不顶边
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const p = ((ctx.raw / totalMins) * 100).toFixed(1);
              return `${ctx.label}（${p}%）`;
            },
          },
        },
      },
    },
  });

  // 自定义图例
  const legend = document.getElementById("chart-legend");
  const meta = pieChart.getDatasetMeta(0).data;
  legend.innerHTML = data
    .map(
      (m, i) =>
        `<li style="color:${meta[i].options.backgroundColor}">${labels[i]}　${(
          (m / totalMins) *
          100
        ).toFixed(1)}%</li>`
    )
    .join("");
}

// 粒度 Tabs
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".scope-tabs .tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelector(".scope-tabs .active")?.classList.remove("active");
      btn.classList.add("active");
      updateStats(btn.dataset.scope);
    });
  });

  // 如果进来就显示统计页，可主动初始化一次
  if (document.getElementById("statsPage")?.classList.contains("active")) {
    updateStats(currentScope);
  }
});

// 在切换到统计页时也更新（如果你的 switchPage 有入口，添加这一句即可）
// 例：switchPage('stats') 分支里调用： updateStats(currentScope);
