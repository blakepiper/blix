(() => {
  const videos = new Set();
  let lastReported = false;
  let leaving = false;

  const isPlaying = video => video.isConnected && !video.paused && !video.ended
    && !video.error && video.videoWidth > 0;

  function state() {
    for (const video of videos) {
      if (!isPlaying(video)) videos.delete(video);
    }
    if (!videos.size) removals.disconnect();
    return !leaving && document.visibilityState === "visible" && videos.size > 0;
  }

  function report() {
    const playing = state();
    if (playing === lastReported) return;
    lastReported = playing;
    browser.runtime.sendMessage({ type: "blix-video-changed" }).catch(() => {});
  }

  // A removed video can keep playing without emitting a media event. Observe
  // removals only while a video plays; never scan the DOM on each mutation.
  const removals = new MutationObserver(records => {
    if (records.some(record => record.removedNodes.length)) report();
  });

  function track(video) {
    if (isPlaying(video)) {
      videos.add(video);
      removals.observe(document, { childList: true, subtree: true });
    } else {
      videos.delete(video);
    }
  }

  function scan() {
    videos.clear();
    for (const video of document.querySelectorAll("video")) track(video);
    report();
  }

  // Capture handles media elements inserted later without a DOM-wide observer.
  // Buffering keeps the window opaque; no timeupdate or frame callbacks run.
  for (const event of ["playing", "pause", "ended", "emptied", "error", "loadedmetadata"]) {
    document.addEventListener(event, event => {
      if (!(event.target instanceof HTMLVideoElement)) return;
      track(event.target);
      report();
    }, true);
  }
  document.addEventListener("visibilitychange", report);
  window.addEventListener("pagehide", () => {
    leaving = true;
    report();
    removals.disconnect();
  });
  window.addEventListener("pageshow", () => {
    leaving = false;
    scan();
  });
  browser.runtime.onMessage.addListener(message => {
    if (message.type === "blix-video-query") return Promise.resolve(state());
  });
  scan();
})();
