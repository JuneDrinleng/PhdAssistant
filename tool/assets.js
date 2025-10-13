// 获取浏览器时区信息
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
const timezoneOffset = -new Date().getTimezoneOffset() / 60;
const timezoneStr =
  timezoneOffset >= 0 ? `UTC+${timezoneOffset}` : `UTC${timezoneOffset}`;
document.getElementById(
  "timezoneInfo"
).textContent = `当前时区: ${timezone} (${timezoneStr})`;

// 页面加载时从localStorage恢复数据
window.addEventListener("DOMContentLoaded", () => {
  const savedUrl = localStorage.getItem("apiUrl");
  const savedKey = localStorage.getItem("apiKey");

  if (savedUrl) document.getElementById("apiUrl").value = savedUrl;
  if (savedKey) document.getElementById("apiKey").value = savedKey;
});

// 将本地时间转换为ISO 8601格式（带时区信息）
function convertToISO(datetimeLocal) {
  const date = new Date(datetimeLocal);
  return date.toISOString().replace("Z", "") + getTimezoneString();
}

// 获取时区字符串，例如 "-07:00" 或 "+08:00"
function getTimezoneString() {
  const offset = -new Date().getTimezoneOffset();
  const hours = Math.floor(Math.abs(offset) / 60);
  const minutes = Math.abs(offset) % 60;
  const sign = offset >= 0 ? "+" : "-";
  return `${sign}${String(hours).padStart(2, "0")}:${String(minutes).padStart(
    2,
    "0"
  )}`;
}

// 显示消息
function showMessage(text, type) {
  const messageEl = document.getElementById("message");
  messageEl.textContent = text;
  messageEl.className = `message ${type}`;
  messageEl.style.display = "block";

  setTimeout(() => {
    messageEl.style.display = "none";
  }, 5000);
}

// 表单提交处理
document.getElementById("focusForm").addEventListener("submit", async (e) => {
  e.preventDefault();

  const apiUrl = document.getElementById("apiUrl").value.trim();
  const apiKey = document.getElementById("apiKey").value.trim();
  const startTime = document.getElementById("startTime").value;
  const endTime = document.getElementById("endTime").value;
  const task = document.getElementById("task").value.trim();

  // 保存URL和API Key到localStorage
  localStorage.setItem("apiUrl", apiUrl);
  localStorage.setItem("apiKey", apiKey);

  // 验证时间
  if (new Date(startTime) >= new Date(endTime)) {
    showMessage("结束时间必须晚于开始时间", "error");
    return;
  }

  // 转换时间格式
  const startTimeISO = convertToISO(startTime);
  const endTimeISO = convertToISO(endTime);

  const submitBtn = document.getElementById("submitBtn");
  submitBtn.disabled = true;
  submitBtn.textContent = "发送中...";

  try {
    // 构建完整URL
    const fullUrl = apiUrl.endsWith("/") ? `${apiUrl}focus` : `${apiUrl}/focus`;

    const response = await fetch(fullUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        start_time: startTimeISO,
        end_time: endTimeISO,
        task: task,
      }),
    });

    if (response.ok) {
      // 尝试解析JSON，如果失败则作为文本处理
      const contentType = response.headers.get("content-type");
      let result;

      try {
        if (contentType && contentType.includes("application/json")) {
          result = await response.json();
        } else {
          result = await response.text();
        }
        showMessage("✅ 专注计划已成功发送！", "success");
        document.getElementById("task").value = ""; // 清空任务内容
        console.log("响应:", result);
      } catch (e) {
        // 如果解析失败，仍然显示成功
        showMessage("✅ 专注计划已成功发送！", "success");
        document.getElementById("task").value = "";
      }
    } else {
      const errorText = await response.text();
      showMessage(`❌ 发送失败: ${response.status} - ${errorText}`, "error");
    }
  } catch (error) {
    showMessage(`❌ 请求错误: ${error.message}`, "error");
    console.error("错误详情:", error);
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "🚀 发送专注计划";
  }
});
