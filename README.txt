Yso systems — November 4, 2026

Maintained: Magi, Alchemist, Apostate, Airlord, shared Yso core, and manual
Dragonform aliases. Active routes are defined by the route registry.

Monk functionality is retired except Deliverance scripts/triggers and their
required compatibility state. Restart the Achaea profile after applying removal.

Runtime: embedded Mudlet package scripts in native load order. Do not use
filesystem require/dofile loaders for routes.

Login: shared Yso.session readiness defers automatic discovery until fresh
character GMCP evidence arrives. TCP connection/cached GMCP do not authenticate.

Updates: rebuild affected XML, run scripts/publish_workspace_link.ps1, then use
ysostatus / ysoreload while automation is stopped. File watches notify only.
The bridge refreshes AK/Yso; changed Legacy/limb packages need separate import.

Maintenance: README.md contains current capabilities, builder guidance, tests,
audit links, and delivery limitations. GIT.md describes safe synchronization.
The retirement manifest removes only explicitly listed, unmodified files.
