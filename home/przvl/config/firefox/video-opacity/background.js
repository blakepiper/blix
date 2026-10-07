const marker = "[blix-video] ";
const pending = new Map();

async function refreshWindow(windowId) {
  const [tab] = await browser.tabs.query({ windowId, active: true });
  if (!tab || tab.discarded) {
    await browser.windows.update(windowId, { titlePreface: "" });
    return;
  }

  // Query the current documents, rather than retaining stale frame state or
  // keeping the background page alive. Cross-origin frames answer separately.
  const frames = await browser.webNavigation.getAllFrames({ tabId: tab.id });
  const states = await Promise.all((frames || []).map(frame =>
    browser.tabs.sendMessage(tab.id, { type: "blix-video-query" }, {
      frameId: frame.frameId,
    }).catch(() => false)
  ));
  const [current] = await browser.tabs.query({ windowId, active: true });
  if (current?.id !== tab.id) return;

  const window = await browser.windows.get(windowId);
  const playing = states.some(state => state === true);
  if (window.title.startsWith(marker) !== playing) {
    await browser.windows.update(windowId, { titlePreface: playing ? marker : "" });
  }
}

function schedule(windowId) {
  // Serialize updates so a slow response cannot overwrite a later tab switch.
  const next = (pending.get(windowId) || Promise.resolve())
    .then(() => refreshWindow(windowId)).catch(() => {});
  pending.set(windowId, next);
  next.finally(() => {
    if (pending.get(windowId) === next) pending.delete(windowId);
  });
  return next;
}

async function refreshAll() {
  const windows = await browser.windows.getAll({ windowTypes: ["normal"] });
  await Promise.all(windows.map(window => schedule(window.id)));
}

browser.runtime.onMessage.addListener((message, sender) => {
  if (message.type === "blix-video-changed" && sender.tab?.active) {
    return schedule(sender.tab.windowId);
  }
});
browser.tabs.onActivated.addListener(({ windowId }) => schedule(windowId));
browser.tabs.onUpdated.addListener((tabId, changes, tab) => {
  if (tab.active && changes.status) schedule(tab.windowId);
});
browser.tabs.onAttached.addListener((tabId, { newWindowId }) => schedule(newWindowId));
browser.tabs.onDetached.addListener((tabId, { oldWindowId }) => schedule(oldWindowId));
browser.runtime.onInstalled.addListener(refreshAll);
browser.runtime.onStartup.addListener(refreshAll);
