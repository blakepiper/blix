// Nix installs this local extension as a trusted built-in. Signature checks
// for ordinary downloaded/profile extensions remain enabled.
// Only OXWM's X11 compositor consumes video markers.
const blixWayland = Services.env.get("XDG_SESSION_TYPE") === "wayland" ||
  !!Services.env.get("WAYLAND_DISPLAY");
const blixXfce = Services.env.get("XDG_CURRENT_DESKTOP") === "XFCE";
// XFCE and labwc provide the window frame; OXWM keeps Firefox's own layout.
defaultPref("browser.tabs.inTitlebar", blixWayland || blixXfce ? 0 : 2);
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
      if (blixWayland || blixXfce) await addon?.disable();
      else await addon?.enable();
    }).catch(Cu.reportError);
  }, "final-ui-startup");
} catch (error) {
  Cu.reportError(error);
}
