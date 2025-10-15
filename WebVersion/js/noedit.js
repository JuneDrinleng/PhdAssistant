// 强制关闭整页编辑模式（有些环境或扩展会打开它）
try {
  document.designMode = "off";
} catch (e) {}
window.addEventListener("load", () => {
  try {
    document.designMode = "off";
  } catch (e) {}
});

// 只允许 input/textarea/真正可编辑的元素接收输入、粘贴、拖放
const allow = (el) =>
  el &&
  (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable);

["beforeinput", "input", "keypress", "keydown", "paste", "drop"].forEach(
  (type) => {
    document.addEventListener(
      type,
      (e) => {
        if (!allow(e.target)) e.preventDefault();
      },
      true
    ); // 捕获阶段拦截，避免生成文本节点
  }
);
