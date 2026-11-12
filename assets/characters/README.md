# Character model goes here

The game has NO realistic character yet - it shows an orange placeholder capsule.

To use a real character:
1. Download a free rigged humanoid (e.g. from Mixamo, Quaternius or Sketchfab with a free license).
2. Export/convert it to `.glb`.
3. Save it here as `survivor.glb`.

`scripts/player.gd` loads `res://assets/characters/survivor.glb` automatically when it exists.
If the file contains an AnimationPlayer, the animations named
`idle`, `walk`, `sprint`, `jump`, `crouch_idle`, `crouch_walk` are played automatically
(rename the animations inside the file if yours use other names).

Always note the source and license of every asset you add (in `ASSETS.md`).
