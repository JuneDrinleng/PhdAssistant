// linkapi.js
const API = "https://phdapi.junedrinleng.com";
const LS_SESSION_KEY = "currentUser";
const LS_TOKEN_KEY = "authToken";

function clearSession() {
  localStorage.removeItem(LS_SESSION_KEY);
  localStorage.removeItem(LS_TOKEN_KEY);
}

// 简单判断是否像 JWT（形如 a.b.c）
function looksLikeJWT(t) {
  return typeof t === "string" && t.split(".").length === 3;
}

// 可选：解析 JWT 是否过期（过期就当作无效）
function isExpiredJWT(t) {
  try {
    const payload = JSON.parse(
      atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    return payload?.exp ? Date.now() / 1000 > payload.exp : false;
  } catch {
    return true;
  }
}

// 只在“后端确认登录有效”时才跳转 dashboard
(async function guard() {
  let user = null,
    token = null;
  try {
    user = JSON.parse(localStorage.getItem(LS_SESSION_KEY) || "null");
    token = localStorage.getItem(LS_TOKEN_KEY);

    // 过滤掉旧的“伪 token”（比如之前 base64(username:password) 的残留）
    if (!user?.username || !looksLikeJWT(token) || isExpiredJWT(token)) {
      clearSession();
      return; // 停留在登录页
    }

    // 向后端校验
    const resp = await fetch(API + "/auth/me", {
      headers: { Authorization: "Bearer " + token },
    });

    if (resp.ok) {
      // 只有后端确认有效才跳转
      location.replace("./dashboard.html");
    } else {
      clearSession(); // 无效会话，停留在登录页
    }
  } catch {
    // 网络异常时，不强跳；保留在登录页
  }
})();

// 登录/注册成功后统一保存会话（只存 JWT，不再写 apiKey）
function setSession(user, token) {
  localStorage.setItem(LS_SESSION_KEY, JSON.stringify(user || {}));
  localStorage.setItem(LS_TOKEN_KEY, token || "");

  // 可选：保存 API 基址（dashboard 里会取这个或默认值）
  localStorage.setItem("apiUrl", API);

  // 清理历史残留
  localStorage.removeItem("apiKey");
}

// 兜底：挂到 window，确保全局可见
window.setSession = setSession;
