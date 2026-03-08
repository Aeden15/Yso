Magi workspace notes
====================

This folder is the class-specific home for Magi work.

Current separation state (2026-03-07):
- Occultist tarot / Domination defensive automation is now gated by class detection and will not auto-emit while you are Magi.
- No Magi-specific defensive automation was added in this pass.
- Future Magi-only offense / defense / resonance helpers should live here rather than inside the Occultist tree.

Added helper modules:
- `magi_vibes.lua` provides `Yso.magi.vibes.run()` for the `vibeds` alias.
- Default embed cadence is `3.40s` to match the current artifact-reduced equilibrium shown in live output.
- Default command list matches the current alias mockup: creeps, oscillate, disorientation, energise, forest, dissonance, plague, lullaby.
- Suggested alias body: `Yso.magi.vibes.run()` if the module is already loaded.
- Paste-ready alias body: `vibeds_alias_body.lua`
- Stop helper: `Yso.magi.vibes.stop()`
