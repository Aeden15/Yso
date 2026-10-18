# Shikudo route sources

`shikudo_forms.lua` owns confirmed form/kata state and the shared
`Yso.monk.shikudo.staff_command()` resolver. Every future Shikudo route must call
that resolver at emission time: it reads the current global `shikstaff`, accepts
only `staff` followed by an item number, and returns a wield command. An empty
configuration uses the confirmed inventory willow-staff fallback; an invalid
configuration holds instead of choosing another weapon. Never copy an item ID
into a route or cache the resolver result across attacks.

`shikudo_ai.lua` selects damage-route options from confirmed state. `combo.lua`
validates Shikudo options against `monk_reference.lua` without sending or changing
tracking. Other routes can share both interfaces. Read target afflictions only
after validating that AK tracks that target. Sending a command never establishes
afflictions, a successful transition, or kata gains.

`shikudo_group_damage.lua` contains the full `shdam` controller adapter, including
mind-lock opening, ranged fallback, Dispatch, and physical recovery gating. Run
`scripts/build_shdam_alias_body.ps1` to regenerate `shdam_alias_body.lua` before
export. The package loads reference, form tracker, combo helper and AI before the
alias can activate. Repeated alias invocation toggles the existing route.

After a confirmation timeout, offense stops. An explicit `shdam` restart clears
the expired request and still waits for current balance/equilibrium readiness.
Ordinary rapid off/on retains recovery protection and cannot duplicate attacks.

Run `scripts/export_yso_system_xml.ps1 -ShikudoOnly -KaiSoarOnly` for the scoped
package refresh, then `scripts/test_shikudo_package.ps1`,
`scripts/test_kai_soar_package.ps1`, and `scripts/test_combat_export.ps1`.

The 24-action Rain and 12-action other-form limits are conservative route policy,
not verified game stumble limits. Tykonos is exempt. The installed damage route
advances Rain after six confirmed actions or a confirmed selected-leg injury/prone
state, with the five-action minimum retained for transitions. The current Dispatch
policy requires confirmed prone and crushedthroat; it retains the installed user
policy without adding a head gate.
