// ===== 统计页面功能 =====
let chartInstance = null;
let timeSlotChartInstance = null;

// 获取统计数据
async function fetchStatistics() {
  const apiUrl = localStorage.getItem("apiUrl");
  const apiKey = localStorage.getItem("apiKey");
  const startDate = document.getElementById("statsStartDate").value;
  const endDate = document.getElementById("statsEndDate").value;

  if (!apiUrl || !apiKey) {
    showStatsError("请先在添加页面设置API URL和API Key");
    return;
  }

  if (!startDate || !endDate) {
    showStatsError("请选择统计时间范围");
    return;
  }

  const loading = document.getElementById("statsLoading");
  const error = document.getElementById("statsError");
  const content = document.getElementById("statsContent");

  loading.style.display = "block";
  error.style.display = "none";
  content.style.display = "none";

  try {
    const fullUrl = apiUrl.endsWith("/") ? `${apiUrl}focus` : `${apiUrl}/focus`;

    const response = await fetch(fullUrl, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });

    if (!response.ok) {
      throw new Error(`请求失败: ${response.status}`);
    }

    let allData = await response.json();

    if (allData.length === 0) {
      showStatsError("没有任何数据");
      return;
    }

    // 1. 先找到整个数据中最早的记录作为"首次相遇"
    const sortedAllData = [...allData].sort(
      (a, b) => new Date(a.start_time) - new Date(b.start_time)
    );
    const firstEverFocus = new Date(sortedAllData[0].start_time);

    // 2. 然后过滤时间范围内的数据用于其他统计
    const start = new Date(startDate);
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999); // 包含结束日期的全天

    const filteredData = allData.filter((item) => {
      const itemDate = new Date(item.start_time);
      return itemDate >= start && itemDate <= end;
    });

    if (filteredData.length === 0) {
      showStatsError("所选时间范围内没有数据");
      return;
    }

    // 处理和显示统计数据
    processStatistics(filteredData, firstEverFocus);

    loading.style.display = "none";

    // 根据屏幕宽度设置正确的display值
    if (window.innerWidth >= 1024) {
      content.style.display = "grid";
      // 桌面端隐藏时间选择器
      document.querySelector(".stats-header").style.display = "none";
    } else {
      content.style.display = "block";
      // 移动端也隐藏时间选择器
      document.querySelector(".stats-header").style.display = "none";
    }
  } catch (err) {
    loading.style.display = "none";
    showStatsError("获取数据失败: " + err.message);
  }
}

function showStatsError(message) {
  const error = document.getElementById("statsError");
  error.textContent = "❌ " + message;
  error.style.display = "block";

  // 显示错误时确保时间选择器可见
  document.querySelector(".stats-header").style.display = "block";
}

// 检查时间是否在深夜时段 (23:00-05:00)
function isLateNight(date) {
  const hour = date.getHours();
  return hour >= 23 || hour < 5;
}

// 处理统计数据
function processStatistics(data, firstEverFocus) {
  // 1. 首次相遇 - 使用整个数据集中最早的记录
  document.getElementById(
    "firstFocusTime"
  ).textContent = `${firstEverFocus.toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  })} ${firstEverFocus.toLocaleTimeString("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
  })}`;

  // 2. 总专注时间和任务分布
  let totalMinutes = 0;
  const taskStats = {};
  let longestSessionMinutes = 0;
  const uniqueDays = new Set();

  data.forEach((item) => {
    const start = new Date(item.start_time);
    const end = new Date(item.end_time);
    const minutes = (end - start) / (1000 * 60);
    totalMinutes += minutes;

    // 记录最长单次专注
    if (minutes > longestSessionMinutes) {
      longestSessionMinutes = minutes;
    }

    // 统计专注天数
    const dateKey = start.toLocaleDateString("zh-CN");
    uniqueDays.add(dateKey);

    // 统计任务分布
    const task = item.task || "未命名任务";
    taskStats[task] = (taskStats[task] || 0) + minutes;
  });

  // 显示总时间
  const hours = Math.floor(totalMinutes / 60);
  const mins = Math.round(totalMinutes % 60);
  document.getElementById(
    "totalFocusTime"
  ).textContent = `${hours}小时${mins}分钟`;

  // 年度报告数据
  document.getElementById("totalSessions").textContent = data.length;

  const avgMinutes = Math.round(totalMinutes / data.length);
  document.getElementById("avgDuration").textContent = `${avgMinutes}分钟`;

  const longestHours = Math.floor(longestSessionMinutes / 60);
  const longestMins = Math.round(longestSessionMinutes % 60);
  document.getElementById("longestSession").textContent =
    longestHours > 0
      ? `${longestHours}小时${longestMins}分钟`
      : `${longestMins}分钟`;

  document.getElementById("activeDays").textContent = uniqueDays.size;

  // 绘制任务分布饼状图
  drawTaskChart(taskStats);

  // 3. 活动时间段统计（柱状图）
  const timeSlots = {
    "凌晨\n0-6点": 0,
    "早晨\n6-9点": 0,
    "上午\n9-12点": 0,
    "下午\n12-18点": 0,
    "晚上\n18-24点": 0,
  };

  data.forEach((item) => {
    const hour = new Date(item.start_time).getHours();
    if (hour >= 0 && hour < 6) timeSlots["凌晨\n0-6点"]++;
    else if (hour >= 6 && hour < 9) timeSlots["早晨\n6-9点"]++;
    else if (hour >= 9 && hour < 12) timeSlots["上午\n9-12点"]++;
    else if (hour >= 12 && hour < 18) timeSlots["下午\n12-18点"]++;
    else timeSlots["晚上\n18-24点"]++;
  });

  drawTimeSlotChart(timeSlots);

  // 4. 最晚专注时刻 - 找到在23:00-05:00时间段内的专注记录
  const lateNightSessions = data.filter((item) => {
    const startTime = new Date(item.start_time);
    const endTime = new Date(item.end_time);
    return isLateNight(startTime) || isLateNight(endTime);
  });

  if (lateNightSessions.length > 0) {
    // 找出这些深夜记录中最晚的时间点
    let latestTime = null;
    lateNightSessions.forEach((item) => {
      const startTime = new Date(item.start_time);
      const endTime = new Date(item.end_time);

      if (isLateNight(endTime) && (!latestTime || endTime > latestTime)) {
        latestTime = endTime;
      }
      if (isLateNight(startTime) && (!latestTime || startTime > latestTime)) {
        latestTime = startTime;
      }
    });

    if (latestTime) {
      const hour = latestTime.getHours();
      const minute = latestTime.getMinutes();
      const timeStr = `${String(hour).padStart(2, "0")}:${String(
        minute
      ).padStart(2, "0")}`;

      let description = "";
      if (hour >= 0 && hour < 5) {
        description = `凌晨 ${timeStr}`;
      } else if (hour >= 23) {
        description = `深夜 ${timeStr}`;
      }

      document.getElementById("latestFocusTime").textContent = description;
    } else {
      document.getElementById("latestFocusTime").textContent =
        "未在深夜时段专注";
    }
  } else {
    document.getElementById("latestFocusTime").textContent = "未在深夜时段专注";
  }

  // 5. 最花时间的任务
  if (Object.keys(taskStats).length > 0) {
    const topTask = Object.entries(taskStats).sort((a, b) => b[1] - a[1])[0];
    const taskName = topTask[0];
    const taskMinutes = topTask[1];
    const taskHours = Math.floor(taskMinutes / 60);
    const taskMins = Math.round(taskMinutes % 60);

    document.getElementById(
      "topTask"
    ).textContent = `${taskName}\n${taskHours}小时${taskMins}分钟`;
  }
}

// 绘制任务分布饼状图
function drawTaskChart(taskStats) {
  const ctx = document.getElementById("taskChart").getContext("2d");

  // 销毁旧图表
  if (chartInstance) {
    chartInstance.destroy();
  }

  const labels = Object.keys(taskStats);
  const dataValues = Object.values(taskStats).map((mins) => Math.round(mins));

  // 生成颜色
  const colors = [
    "#667eea",
    "#764ba2",
    "#f093fb",
    "#4facfe",
    "#43e97b",
    "#fa709a",
    "#fee140",
    "#30cfd0",
    "#a8edea",
    "#fed6e3",
    "#c471ed",
    "#f64f59",
  ];

  chartInstance = new Chart(ctx, {
    type: "pie",
    data: {
      labels: labels,
      datasets: [
        {
          data: dataValues,
          backgroundColor: colors.slice(0, labels.length),
          borderWidth: 2,
          borderColor: "#fff",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: "bottom",
          labels: {
            padding: 10,
            font: {
              size: 10,
            },
          },
        },
        tooltip: {
          callbacks: {
            label: function (context) {
              const label = context.label || "";
              const value = context.parsed;
              const hours = Math.floor(value / 60);
              const mins = Math.round(value % 60);
              return `${label}: ${hours}h ${mins}m`;
            },
          },
        },
      },
    },
  });
}

// 绘制活动时间段柱状图
function drawTimeSlotChart(timeSlots) {
  const ctx = document.getElementById("timeSlotChart").getContext("2d");

  // 销毁旧图表
  if (timeSlotChartInstance) {
    timeSlotChartInstance.destroy();
  }

  const labels = Object.keys(timeSlots);
  const dataValues = Object.values(timeSlots);

  timeSlotChartInstance = new Chart(ctx, {
    type: "bar",
    data: {
      labels: labels,
      datasets: [
        {
          label: "专注次数",
          data: dataValues,
          backgroundColor: [
            "rgba(102, 126, 234, 0.8)",
            "rgba(250, 112, 154, 0.8)",
            "rgba(254, 225, 64, 0.8)",
            "rgba(67, 233, 123, 0.8)",
            "rgba(118, 75, 162, 0.8)",
          ],
          borderColor: ["#667eea", "#fa709a", "#fee140", "#43e97b", "#764ba2"],
          borderWidth: 2,
          borderRadius: 8,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          callbacks: {
            label: function (context) {
              return `专注次数: ${context.parsed.y} 次`;
            },
          },
        },
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            stepSize: 1,
            font: {
              size: 12,
            },
          },
          grid: {
            color: "rgba(0, 0, 0, 0.05)",
          },
        },
        x: {
          ticks: {
            font: {
              size: 12,
            },
          },
          grid: {
            display: false,
          },
        },
      },
    },
  });
}

// 窗口大小改变时更新display
window.addEventListener("resize", () => {
  const content = document.getElementById("statsContent");
  const header = document.querySelector(".stats-header");

  if (content.style.display !== "none") {
    if (window.innerWidth >= 1024) {
      content.style.display = "grid";
      header.style.display = "none";
    } else {
      content.style.display = "block";
      // 移动端显示内容时也隐藏选择器
      header.style.display = "none";
    }
  }
});
