Yso systems — November 5, 2026

Maintained: Magi, Alchemist, Apostate, Airlord, shared Yso core, and manual
Dragonform aliases. Active routes are defined by the route registry.

Alchemist offense is temporarily suspended, including aliases and hunting.
Sources/tracking/self-curing remain. Explicit future enable only after access.

ysocheck: read-only unified runtime readiness and diagnostics.
scripts/verify_yso.ps1: unified local/CI verification with JSON results.
scripts/build_yso_release.ps1: verified coordinated release build.
ysoinstall: full bundle install while already disconnected; restart required.
Never disconnects the game. No live installation is performed by workspace tools.

Discord posting/embedded webhooks and independent Legacy updates are removed.
NDB is cache-only until a secure character endpoint is verified.

Monk functionality is retired except Deliverance scripts/triggers and their
required compatibility state. Restart the Achaea profile after applying removal.

Runtime: embedded Mudlet package scripts in native load order. Do not use
filesystem require/dofile loaders for routes.

Login: shared Yso.session readiness defers automatic discovery until fresh
character GMCP evidence arrives. TCP connection/cached GMCP do not authenticate.

Updates: rebuild affected XML, run scripts/publish_workspace_link.ps1, then use
ysostatus / ysoreload while automation is stopped. File watches notify only.
Hot reload refreshes AK/Yso; full releases include Legacy/UI/Basher and limb.

Maintenance: README.md contains current capabilities, builder guidance, tests,
audit links, and delivery limitations. GIT.md describes safe synchronization.
The retirement manifest removes only explicitly listed, unmodified files.
