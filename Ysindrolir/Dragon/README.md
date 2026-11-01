# Dragonform manual aliases

The nine aliases in the Dragonform folder of `mudlet packages/Yso system.xml`
are manual overrides. Each calls `sendAll("cq all", ...)` to clear server queues
before sending the skill immediately, bypassing automation readiness checks.
Targeted skills still use `Yso.dragon.target()` and send nothing if the target
is missing or invalid. The `atk` alias sends sensitivity curse with delay `1`,
then rend with curare, after one queue clear. Limb rend remains disabled.

The package XML is the maintained source for these aliases. Shared Dragon
helpers retain their existing checks for other callers.

Run `scripts/test_dragon_manual_aliases.ps1` to check all nine command sequences,
readiness bypass, invalid targets, and alias Lua syntax. After updating the
package, run `scripts/publish_workspace_link.ps1` to refresh local validation
snapshots for `ysoreload`.
