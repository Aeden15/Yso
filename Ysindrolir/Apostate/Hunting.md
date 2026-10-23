# Apostate hunting with Legacy

Import **Legacy Basher V2.1.xml** after updating. Its existing `hunt` toggle
arms a Soulstorm opener when your class is Apostate.

The first eligible denizen attack queues `soulstorm <current denizen ID>` before
the ordinary `basher` command. It uses the existing `freestand` queue, so the
normal attack follows Soulstorm's actual recovery. No four-second delay is
invented: the AB states that recovery against denizens is reduced.

The opener respects the basher's balance/equilibrium, health, fleeing, target,
affliction and Fool holds. If hunting starts without a target, it waits for the
first valid denizen. The class attack, prepend, and rage settings are unchanged.
Other classes keep their normal behavior, including Occultist's Attend opener.

The captured messages update `Legacy.Basher.Soulstorm.effect`:

- The successful cast and “Necromantic essence still profanes …” confirm the
  effect for the matching current denizen and room.
- “… steadies as the profane aura around it fades” clears the matching effect.
- A confirmed active effect is retained across off/on toggles, preventing a
  duplicate opener on that denizen before it fades.

The user-confirmed duration is 40 seconds. The cache expires after that interval
if the fade message is missed. An already-active report does not extend a known
expiry. This duration is separate from equilibrium recovery, which the server's
queue handles normally.

This is one opener per `hunt` activation. Expiry clears the active state but
does not repeatedly cast during the same hunting session or on every new mob.
No commands are sent by the confirmation triggers. Target changes cannot
confirm the old queued target as the new target. Leaving the room discards cached
effects, since expiry may occur out of sight; disconnect/class changes also
clear tracked effects. If a queue send throws, hunting stops and clears its queue
rather than retrying a potentially partial opener indefinitely.

Maintain the helper in `hunting_soulstorm.lua`. Synchronize the Legacy package
with `scripts/build_apostate_hunting_package.ps1` and verify with
`scripts/test_apostate_hunting.ps1`. The regression test replays the real Legacy
toggle, attack function, queue helper, and trigger adapters without game sends.
