const $ = (s) => document.querySelector(s);

const loginForm = $("#loginForm");
const registerForm = $("#registerForm");
const loginMsg = $("#loginMsg");
const registerMsg = $("#registerMsg");
const toRegister = $("#toRegister");
const toLogin = $("#toLogin");
const regTitle = $("#registerTitle");
const toLoginWrap = $("#toLoginWrap");

const loginTitle = $("#loginTitle");
const toRegisterWrap = $("#toRegisterWrap");
const divider = $("#divider");

function showLogin() {
  // 显示登录区
  loginForm.style.display = "";
  loginTitle.style.display = "";
  toRegisterWrap.style.display = "";
  divider.style.display = "";

  // 清理并隐藏注册区
  registerForm.style.display = "none";
  registerMsg.style.display = "none";
  regTitle.style.display = "none";
  toLoginWrap.style.display = "none";

  // 清理登录错误提示的残留
  loginMsg.style.display = "none";
}

function showRegister() {
  // 隐藏登录区（标题、链接、分隔线、错误框一并隐藏）
  loginForm.style.display = "none";
  loginTitle.style.display = "none";
  toRegisterWrap.style.display = "none";
  divider.style.display = "none";
  loginMsg.style.display = "none";

  // 显示注册区
  registerForm.style.display = "";
  regTitle.style.display = "";
  toLoginWrap.style.display = "";
  registerMsg.style.display = "none";
}

toRegister.addEventListener("click", showRegister);
toLogin.addEventListener("click", showLogin);

// 通用 POST JSON
async function postJSON(path, payload) {
  const resp = await fetch(API + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data.error || resp.statusText || "请求失败");
  }
  return data; // 期望 { token, user }
}

// 登录 -> /auth/login
loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  loginMsg.className = "message";
  loginMsg.style.display = "none";

  const username = $("#loginUsername").value.trim();
  const password = $("#loginPassword").value;

  const btn = loginForm.querySelector('button[type="submit"]');
  btn.disabled = true;

  try {
    const { token, user } = await postJSON("/auth/login", {
      username,
      password,
    });
    setSession(user, token);
    location.replace("./dashboard.html");
  } catch (err) {
    loginMsg.classList.add("error");
    loginMsg.textContent = err.message || "登录失败";
    loginMsg.style.display = "block";
  } finally {
    btn.disabled = false;
  }
});

// 注册 -> /auth/register
registerForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  registerMsg.className = "message";
  registerMsg.style.display = "none";

  const username = $("#regUsername").value.trim();
  const password = $("#regPassword").value;
  if (!username || !password) return;

  const btn = registerForm.querySelector('button[type="submit"]');
  btn.disabled = true;

  try {
    const { token, user } = await postJSON("/auth/register", {
      username,
      password,
    });
    setSession(user, token);
    location.replace("./dashboard.html");
  } catch (err) {
    registerMsg.classList.add("error");
    // 兼容后端 {error:"username exists"}
    registerMsg.textContent = /exist|已存在/i.test(err.message)
      ? "该用户名已存在，请更换一个。"
      : err.message || "注册失败";
    registerMsg.style.display = "block";
  } finally {
    btn.disabled = false;
  }
});
