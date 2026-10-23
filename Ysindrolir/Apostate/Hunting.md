# Apostate hunting with Legacy

Import **Legacy Basher V2.1.xml** after updating. Its existing `hunt` toggle
enables a Soulstorm opener for each denizen Legacy selects when your class is Apostate.

The first eligible attack on each denizen queues `soulstorm <current denizen ID>` before
the ordinary `basher` command. It uses the existing `freestand` queue, so the
normal attack follows Soulstorm's actual recovery. No four-second delay is
invented: the AB states that recovery against denizens is reduced.

The opener respects the basher's balance/equilibrium, health, fleeing, target,
affliction and Fool holds. If hunting starts without a target, it waits for the
first valid denizen. The class attack, prepend, and rage settings are unchanged.
Other classes keep their normal behavior, including Occultist's Attend opener.

The Soulstorm runtime is reinstalled after Legacy restores saved tables. Its
live event-handler IDs stay outside saved Legacy data so old IDs cannot remove
unrelated handlers. Setup clears transient target state, and enabling `hunt`
scans the current room before selecting a target. Room list/add/remove events
maintain a live mob cache, including mobs with combined `mx` flags; arrivals
can be selected even when the last full room list was empty.

The `hor` alias in **Yso system.xml** requires Apostate and at least 29 rage
from `gmcp.Char.Vitals.charstats`. It prefers `gmcp.IRE.Target.Set`, falling
back to the existing global target when no server target is set. It does not
track Horrify's cooldown locally.

The captured messages update `Legacy.Basher.Soulstorm.effect`:

- The successful cast and “Necromantic essence still profanes …” confirm the
  effect for the matching current denizen and room.
- “… steadies as the profane aura around it fades” clears the matching effect.
- Opener state is retained across off/on toggles, preventing a duplicate opener
  on the same surviving denizen even if the effect has faded.

The user-confirmed duration is 40 seconds. The cache expires after that interval
if the fade message is missed. An already-active report does not extend a known
expiry. This duration is separate from equilibrium recovery, which the server's
queue handles normally.

This is one opener per individual denizen, using Legacy's existing `currentTar`
and target selection. Slain and room-removal handling clear that denizen's state
before advancing to the next target. The slain denizen is removed from Legacy's
candidate and live-room caches so it cannot be selected again while waiting for
GMCP updates. If GMCP removes the mob before its slain line arrives, the slain
line clears the removed mob rather than the already-selected successor.
This removal/slain association lasts through the current server output batch
and expires at the next Vitals-driven attack check. A fleeing mob cannot retain
that association and consume a later same-named mob's slain message.

Expiry clears the active-effect flag but does not refresh Soulstorm on a
surviving denizen. Switching back to that denizen does not repeat its opener.
No commands are sent by the confirmation triggers. Target changes cannot
confirm the old queued target as the new target. Leaving the room discards cached
effects, since expiry may occur out of sight; disconnect/class changes also
clear tracked effects. If a queue send throws, hunting stops and clears its queue
rather than retrying a potentially partial opener indefinitely.

Maintain the helper in `hunting_soulstorm.lua`. Synchronize the Legacy package
with `scripts/build_apostate_hunting_package.ps1` and verify with
`scripts/test_apostate_hunting.ps1`. The regression test replays the real Legacy
toggle, attack function, queue helper, and trigger adapters without game sends.
