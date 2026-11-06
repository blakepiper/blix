// Nix installs this local extension as a trusted built-in. Signature checks
// for ordinary downloaded/profile extensions remain enabled.
// Native Wayland is opaque; only the X11 compositor consumes video markers.
const blixWayland = Services.env.get("XDG_SESSION_TYPE") === "wayland" ||
  !!Services.env.get("WAYLAND_DISPLAY");
// Ask Firefox to use the compositor titlebar, avoiding a second client frame.
defaultPref("browser.tabs.inTitlebar", blixWayland ? 0 : 2);
try {
  const { AddonManager } = ChromeUtils.importESModule("resource://gre/modules/AddonManager.sys.mjs");
  Services.io.getProtocolHandler("resource").QueryInterface(Ci.nsIResProtocolHandler)
    .setSubstitution("blix-video-opacity", Services.io.newURI("file://@video-opacity-source@/"));
  Services.obs.addObserver(function installBlixVideoOpacity() {
    Services.obs.removeObserver(installBlixVideoOpacity, "final-ui-startup");
    AddonManager.maybeInstallBuiltinAddon(
      "video-opacity@blix.local", "@video-opacity-version@", "resource://blix-video-opacity/"
    ).then(async () => {
      const addon = await AddonManager.getAddonByID("video-opacity@blix.local");
      if (blixWayland) await addon?.disable();
      else await addon?.enable();
    }).catch(Cu.reportError);
  }, "final-ui-startup");
} catch (error) {
  Cu.reportError(error);
}
