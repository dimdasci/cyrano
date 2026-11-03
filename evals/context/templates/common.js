// Shared helpers for the synthetic window templates (docs/specs/04-prompts.md §5).
// A template defines render(data, draft); cyrano-eval calls it after the page loads.

function esc(text) {
  return String(text ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}

/// Text with blank lines as paragraphs and single line breaks kept.
function paragraphs(text) {
  return String(text ?? "").split(/\n{2,}/).map((p) => `<p>${esc(p).replace(/\n/g, "<br>")}</p>`).join("");
}

const palette = ["#5b5fc7", "#c4314b", "#0f7b6c", "#ca5010", "#8764b8", "#038387", "#986f0b", "#4f6bed"];

function initials(name) {
  return String(name).split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join("").toUpperCase();
}

function avatar(name, size = 32) {
  const color = palette[[...String(name)].reduce((sum, c) => sum + c.charCodeAt(0), 0) % palette.length];
  return `<div class="avatar" style="width:${size}px;height:${size}px;background:${color};font-size:${size * 0.38}px">${esc(initials(name))}</div>`;
}

/// The macOS window: a browser with tabs and an address bar, or an app with a title.
function frame(window, content) {
  const lights = `<div class="lights"><i></i><i></i><i></i></div>`;
  if (window.browser) {
    const tabs = window.browser.tabs.map((t, i) => `<div class="tab ${i === window.browser.active ? "on" : ""}">${esc(t)}</div>`).join("");
    return `<div class="window"><div class="titlebar">${lights}<div class="tabs">${tabs}</div></div>
      <div class="toolbar"><span>‹</span><span>›</span><span>↻</span><div class="url">${esc(window.browser.url)}</div><span class="icon"></span><span class="icon"></span></div>
      <div class="content">${content}</div></div>`;
  }
  return `<div class="window"><div class="titlebar">${lights}<div class="apptitle">${esc(window.title ?? "")}</div></div>
    <div class="content">${content}</div></div>`;
}

function overlays(list) {
  return (list ?? []).map((o) => `<div class="toast ${o.position ?? "top"}"><small>${esc(o.app)}</small><b>${esc(o.title)}</b>${esc(o.text)}</div>`).join("");
}

function show(window, content, extra) {
  document.body.innerHTML = frame(window, content + overlays(extra));
}
