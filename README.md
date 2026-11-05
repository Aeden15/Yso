# Yso systems — November 5, 2026

Yso runs from the embedded Lua in the Mudlet packages under `Ysindrolir/mudlet packages/`. Filesystem Lua is maintained source and test input, not a runtime route loader.

## Maintained capabilities

- **Magi:** focus/lock, duel damage, Firestorm and water group routes, equipment discovery, vibes, and Stormhammer helpers.
- **Alchemist:** offense is temporarily suspended, including route starts, offensive aliases, queued attacks, and Legacy hunting. Physiology, formulation sources, tracking, and self-curing helpers are retained for future access.
- **Apostate:** Truelocks, Vivisect, tracking, entourage, and Soulstorm hunting support.
- **Airlord:** separate lock and damage routes, Compression, and soar helpers.
- **Dragonform:** manual aliases; see [Dragon commands](Ysindrolir/Dragon/README.md).
- **Shared:** curing/self-state, target intelligence, route scheduling, command emission, parry, and AK/Legacy integration.

These are maintained package capabilities, not a claim that every route is verified against a live game session. The route registry determines active combat routes.

**Monk is retired.** Monk routes, skill stacks, class-specific opponent handling, and build/test tooling are removed. **Deliverance is the explicit exception:** its own activation and lifecycle scripts/triggers, enemy protection, and required Kai compatibility state remain. They live under shared combat sources; `Yso.monk.kai` remains only for these retained integrations. Generic limb and affliction infrastructure remains available to other classes.

## Unified checks and coordinated releases

Use **`ysocheck`** in Mudlet for a read-only report of session readiness, package/release consistency, curing, route blockers, queued work, equipment, supplies, startup work, and required restarts. It never sends gameplay commands or changes automation. An intentionally suspended class is reported as disabled, not broken.

Run one workspace command with PowerShell 7, `lua` and `luac` on PATH:

```powershell
pwsh -NoProfile -File './Ysindrolir/scripts/verify_yso.ps1'
```

It runs syntax/security/parity checks, standalone suites with their fixtures, and all package wrappers. It prints the location of its JSON report and per-check logs; failures return a nonzero exit code. GitHub Actions runs the same command with checksum-verified Lua 5.4.8 sources.

After rebuilding affected XMLs, run `Ysindrolir/scripts/build_yso_release.ps1`. It verifies the inputs and publishes an immutable local bundle under `Ysindrolir/releases/`, selected by `current.json`. The release includes Legacy Core, AK, limb support, Yso, Legacy Basher, Legacy UI, and the independent workspace controller. Existing package identities and profile settings are retained.

Import the built **Yso Workspace Link** package as the bootstrap controller. When you have logged out normally, use **`ysoinstall`** to install the verified full bundle. Installation refuses a connected or unknown connection state; it never disconnects the game. It backs up the profile, checks all package bytes and native Lua before replacement, and requires a profile restart before connecting or resuming automation. Full updates use Mudlet 4.12+ connection-state APIs.

For subsequent verified AK/Yso-only changes, the existing `ysoreload` path remains available while automation is stopped. Changes to Legacy, Basher, UI, limb, or the controller require the full offline install and restart. Optional `Target things` and older standalone Stormhammer exports are excluded from automatic installation because they can overlap maintained functionality.

## Login and source updates

The shared `Yso.session` service waits for fresh character GMCP evidence before automatic equipment, formulation, or curing-policy discovery. A TCP connection and cached character tables do not establish authentication. Disconnect/reconnect invalidates readiness and deferred work; ordinary user login input is untouched.

The independent **Yso Workspace Link** package watches built XMLs and reports pending changes. **Updates still require `ysoreload`.** It reloads AK before Yso while automation is stopped; it never starts a route automatically.

1. Edit the maintained source or package-native entry.
2. Rebuild the affected XML with its scoped builder. Use `scripts/build_login_safety_package.ps1` for session/discovery changes, `build_airlord_soar_package.ps1` for soar, or `build_deliverance_package.ps1` for retained Deliverance support.
3. For Legacy login changes, also run `Ysindrolir/scripts/build_legacy_login_safety_package.ps1`; this deliberately updates Legacy separately from Yso exports.
4. Run `Ysindrolir/scripts/publish_workspace_link.ps1` to publish byte-exact validation receipts.
5. With automation stopped, use `ysostatus`, then `ysoreload` in Mudlet.

See [workspace-link setup and recovery](Ysindrolir/Information/workspace-link.md). Native modules use profile-local copies, never editable workspace sources. Full releases use `build_yso_release.ps1` and `ysoinstall`; publishing workspace-link receipts alone does not publish a complete release.

**Restart the Achaea profile after a full installation.** Removing XML entries does not reliably erase globals or anonymous handlers from the previous live Lua session. The coordinated installer includes Legacy and support packages; `ysoreload` remains the narrower AK/Yso update path. No live installation is implied by a workspace rebuild.

## Temporary Alchemist suspension and networking

`Yso.features.alchemist_offense` defaults to `false`. Keep it disabled until class access returns. A future explicit re-enable uses `Yso.alchemist_offense.set_enabled(true)`; loading or checking the system never enables it automatically. Shared opponent tracking and defensive/self-curing helpers remain available. Physiology diagnostics are optional trace events and never write to a hard-coded Desktop file or require `yajl` serialization.

Legacy Discord feedback and installation reporting are local-only; no webhook credentials are distributed. Legacy's independent updater is disabled so it cannot replace the managed release. Exposed historical webhook tokens require revocation by their owners; removing source strings does not revoke remote credentials.

NDB uses validated cached records. Insecure HTTP character refresh is disabled because a working secure endpoint has not been verified. Cached online-player data is historical and may be stale; `ysocheck` reports that limitation.

## Source and build contracts

- Mudlet script load order supplies globals. Do not activate routes through runtime `require`, `dofile`, root probing, `YSO_ROOT`, or `package.path` changes.
- `Yso/xml/api_stuff.lua` is the command API source of truth. Routes use `Yso.emit` / `Yso.emit_now`; legacy queue modules remain only where compatibility/tests require them.
- Shared session readiness loads before automatic discovery consumers.
- The full exporter is `Ysindrolir/scripts/export_yso_system_xml.ps1`; scoped builders preserve unrelated package-native entries. Test full exports in disposable copies before adopting their output.
- Rebuilds and publishing local receipts do not commit, push, or apply an update in Mudlet.

## Verification and audit

Regression scripts live under `Ysindrolir/scripts/test_*.ps1`; standalone Lua regressions also live under `Ysindrolir/Yso/Tests and rebuilds/` and `Ysindrolir/Apostate/`. Some Lua tests need package-extracted fixtures and should run through their PowerShell wrapper.

Use PowerShell 7 (`pwsh`) for package builds and regression wrappers, with `lua`/`luac` on PATH. The synchronization helper also supports Windows PowerShell 5.1 used by `sync.cmd`. Local CLI tests use Mudlet mocks and do not replace verification in the live profile.

Relevant maintenance checks include `test_workspace_link_package.ps1`, `test_workspace_sync.ps1`, `test_monk_retirement.ps1`, `test_stormhammer_package.ps1`, and `test_full_export_safety.ps1`.

See [maintenance findings and next steps](Ysindrolir/Information/maintenance-audit-2026-11-04.md) for verification evidence, remaining limits, and the enhancement backlog. The [October source audit](Ysindrolir/Information/Yso-source-audit.md) is historical context.

## Workspace and Git

This Desktop folder is an editing workspace. The canonical clone is `C:/Users/shuji/OneDrive/Documents/GitHub/Yso`; Git commands belong there. See [Git workflow](GIT.md).

Sync uses content hashes and an explicit retirement manifest, not unrestricted mirroring. It preserves unrelated destination files and refuses deletion of a modified retired file. Preview with `Ysindrolir/scripts/Invoke-YsoGit.ps1 -DryRun`; no Git command runs in this mode. Local workspace-link receipts are excluded and must be regenerated locally.
