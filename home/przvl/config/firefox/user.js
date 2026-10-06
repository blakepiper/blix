
// Load custom styling for the Firefox browser interface.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Native two-finger touchpad swipes navigate browser history under X11.
user_pref("widget.disable-swipe-tracker", false);
user_pref("browser.gesture.swipe.left", "Browser:BackOrBackDuplicate");
user_pref("browser.gesture.swipe.right", "Browser:ForwardOrForwardDuplicate");

// Privacy: strict tracking protection, no usage uploads or remote search suggestions,
// and HTTPS-Only in all windows. Applied whenever Firefox starts.

// Enable Mozilla Accounts for the built-in VPN; disable pairing and account promotions.
user_pref("identity.fxaccounts.enabled", true);
user_pref("identity.fxaccounts.toolbar.enabled", false);
user_pref("identity.fxaccounts.toolbar.defaultVisible", false);
user_pref("identity.fxaccounts.toolbar.pxiToolbarEnabled", false);
user_pref("identity.fxaccounts.pairing.enabled", false);
user_pref("identity.fxaccounts.commands.remoteTabManagement.enabled", false);
user_pref("identity.fxaccounts.telemetry.clientAssociationPing.enabled", false);
user_pref("identity.fxaccounts.telemetry.clientInfoPing.enabled", false);
user_pref("browser.promo.relay.enabled", false);

// Privacy hardening: tracking isolation and no speculative traffic.
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("network.cookie.cookieBehavior", 5);
// Keep canvas-based image uploads and pastes working. Tracking protection stays enabled.
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.resistFingerprinting.pbMode", false);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("media.peerconnection.ice.default_address_only", true);

// Keep the icon-only vertical tab strip visible when collapsed or resized.
user_pref("sidebar.visibility", "always-show");

// Use the dark theme in the built-in PDF viewer.
user_pref("pdfjs.viewerCssTheme", 2);

// Render PDF pages with a dark background and light text.
user_pref("pdfjs.forcePageColors", true);
user_pref("pdfjs.pageColorsBackground", "#181818");
user_pref("pdfjs.pageColorsForeground", "#eeeeee");

// Appearance settings extracted from the local saved preferences.
user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
user_pref("browser.theme.toolbar-theme", 0);
user_pref("sidebar.verticalTabs", true);
user_pref("browser.newtabpage.enabled", false);

// Later preference: override document fonts; this can change site layout.
user_pref("font.default.x-western", "sans-serif");
user_pref("font.name.serif.x-western", "JetBrainsMono Nerd Font");
user_pref("font.name.sans-serif.x-western", "JetBrainsMono Nerd Font");
user_pref("font.name.monospace.x-western", "JetBrainsMono Nerd Font Mono");
user_pref("font.name.serif.x-unicode", "JetBrainsMono Nerd Font");
user_pref("font.name.sans-serif.x-unicode", "JetBrainsMono Nerd Font");
user_pref("font.name.monospace.x-unicode", "JetBrainsMono Nerd Font Mono");
user_pref("browser.display.use_document_fonts", 0);
