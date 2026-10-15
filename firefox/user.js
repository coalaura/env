/* Custom CSS */

user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // Enable custom CSS
user_pref("services.sync.prefs.sync.toolkit.legacyUserProfileCustomizations.stylesheets", true); // Sync CSS preference

/* Browser UI & Behavior */

user_pref("browser.urlbar.trimURLs", false); // Show complete URLs
user_pref("browser.download.manager.addToRecentDocs", false); // Exclude downloads from Windows Recent

/* Tracking & Privacy */

user_pref("browser.contentblocking.category", "strict"); // Strict tracker blocking
user_pref("privacy.globalprivacycontrol.enabled", true); // Send privacy opt-out signal
user_pref("network.http.referer.XOriginTrimmingPolicy", 2); // Trim cross-origin referrers

/* Security */

user_pref("dom.security.https_only_mode", true); // Enforce HTTPS
user_pref("security.tls.enable_0rtt_data", false); // Disable TLS early data
user_pref("security.ssl.require_safe_negotiation", true); // Require secure TLS renegotiation
user_pref("security.cert_pinning.enforcement_level", 2); // Enforce strict certificate pinning
user_pref("network.file.disable_unc_paths", true); // Block UNC file access
user_pref("network.IDN_show_punycode", true); // Expose Unicode lookalike domains
user_pref("pdfjs.enableScripting", false); // Disable PDF scripting

/* Permissions & Credentials */

user_pref("permissions.default.desktop-notification", 2); // Block notification requests
user_pref("signon.autofillForms", false); // Disable password autofill

/* Telemetry & Experiments */

user_pref("datareporting.healthreport.uploadEnabled", false); // Disable health reports
user_pref("datareporting.policy.dataSubmissionEnabled", false); // Disable data submission
user_pref("datareporting.usage.uploadEnabled", false); // Disable usage reporting
user_pref("toolkit.telemetry.archive.enabled", false); // Disable telemetry archive
user_pref("app.shield.optoutstudies.enabled", false); // Disable studies

/* Recommendations & Sponsored Content */

user_pref("browser.newtabpage.activity-stream.showSponsored", false); // Hide sponsored stories
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false); // Hide sponsored shortcuts
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false); // Hide sponsored checkboxes
user_pref("browser.urlbar.quicksuggest.enabled", false); // Disable Firefox Suggest
user_pref("browser.urlbar.suggest.quicksuggest.all", false); // Disable contextual suggestions
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false); // Disable sponsored suggestions
user_pref("browser.urlbar.trending.featureGate", false); // Hide trending searches
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false); // Hide add-on recommendations
user_pref("browser.discovery.enabled", false); // Disable personalized recommendations
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false); // Disable add-on promotions
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false); // Disable feature promotions

/* AI Features */

user_pref("browser.ai.control.default", "blocked"); // Block AI enhancements
