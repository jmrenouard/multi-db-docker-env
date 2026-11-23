function renderMdbMath() {
  if (typeof renderMathInElement !== "function") return;
  renderMathInElement(document.body, {
    delimiters: [
      { left: "$$", right: "$$", display: true },
      { left: "$", right: "$", display: false },
      { left: "\\(", right: "\\)", display: false },
      { left: "\\[", right: "\\]", display: true }
    ],
    ignoredTags: ["script", "noscript", "style", "textarea", "pre", "code"],
    throwOnError: false
  });
}
if (typeof document$ !== "undefined") {
  document$.subscribe(() => typeof renderMathInElement === "function" ? renderMdbMath() : window.addEventListener("DOMContentLoaded", renderMdbMath, { once: true }));
} else if (document.readyState === "loading") {
  window.addEventListener("DOMContentLoaded", renderMdbMath, { once: true });
} else {
  renderMdbMath();
}
