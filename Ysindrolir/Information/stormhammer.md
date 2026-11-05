# Stormhammer and priority targets

These features are embedded in `mudlet packages/Yso system.xml`. Original
`stormhammer aliases.xml`, `stormhammer script.xml`, and `Target things.xml`
are reference imports, not additional packages to enable alongside Yso.

- `tgh Bob Alice Carol` replaces the ordered priority list; commas are accepted.
- `tpf`, `tpn`, `tpl` select the first, next, or previous priority target through
  Yso's targeting API. Empty lists do nothing; targeting locks remain effective.
- `tp` announces `Priority Targets: Bob, Alice, Carol.` to the party.
  The supplied party trigger accepts both Targets and Priority Targets calls.
- `ept` / `etp` clears the enemy list and enemies each priority target.
- `prep` toggles Yso's existing party-reporting flag.
- `shtar List` (default) selects the current room target first, then present
  priority targets. `shtar All` fills remaining places alphabetically from room
  players. Both exclude self and souls, deduplicate, and stop at three targets.
  All is deliberately broad: other present adventurers can be selected.
- `sth` queues the supplied stand/wield/Stormhammer server alias. It does not
  clear other queues. `ham` remains available for explicitly named targets.
- `tfix` clears all queues and casts Transfix at the global `target`, exactly
  as requested.

When the current target leaves or is absent from a room-player update, the first
present priority target becomes Yso's shared target. No available priority target
leaves the current target unchanged.

## Equipment

`Yso.magi.weapons` discovers an elemental staff and shield from GMCP inventory
List/Add/Update/Remove messages and populates `magistaff` / `magishield` with
full references such as `staff60009` / `shield221004`. These IDs can change.
The selected item is the wielded matching item, then the previous item if still
present, then the sole matching inventory item. Ambiguous selection stays empty.

`eq`, `ii staff`, and `ii shield` responses also update discovery. `sth` requests
an inventory refresh and these listings if equipment is unresolved; retry after
the responses arrive. It never queues an incomplete cast. With several unwielded
candidates, wield the intended item, or select a confirmed inventory item using
`Yso.magi.weapons.set("shield", "shield123")` (likewise for staff).

Connecting alone never sends equipment commands: automatic discovery waits for
a fresh authenticated character Status/Vitals event. Disconnect and reconnect
clear that readiness, so cached GMCP cannot inject `eq` into password prompts.

Text discovery finishes on a native Mudlet prompt trigger and expires after
eight seconds if no complete response arrives. GMCP remains the primary source.
Protocol references: [Achaea GMCP specification](https://www.achaea.com/local/Achaea_GMCP_Spec_20140311.pdf),
[IRE item attributes](https://github.com/keneanung/GMCPAdditions), and
[Mudlet prompt triggers](https://wiki.mudlet.org/w/Manual:Lua_Functions#tempPromptTrigger).

## Maintenance

From the workspace root:

```powershell
./Ysindrolir/scripts/export_yso_system_xml.ps1 -StormhammerOnly
./Ysindrolir/scripts/test_stormhammer_package.ps1
./Ysindrolir/scripts/publish_workspace_link.ps1
```

The scoped builder preserves unrelated entries and is byte-idempotent. Apply via
`ysoreload` while combat/hunting automation is stopped. Disable the original
standalone imports before use to prevent duplicate alias/trigger execution.
