# ALONE MAN - SURVIVE ALONE. BUILD YOUR LIFE.

Godot 4.3, GL Compatibility renderer, Android first, offline.

## Status: PHASE 1 (not yet tested on a real phone)

Included:
- Third-person camera (swipe on the right half of the screen to rotate, with camera collision)
- Floating joystick (left half); push beyond the ring to sprint
- Camera-relative movement, jump, crouch toggle
- USE button (picks up the test crates)
- Basic HUD: health/hunger/thirst/stamina bars, compass + clock, notification text, empty hotbar, FPS counter
- GitHub Actions workflow that builds a debug APK

NOT included yet (honest list):
- Realistic character, animations, forest, terrain, sounds (need real assets - see assets/characters/README.md)
- Working hunger/thirst/health, inventory, crafting, saving (Phase 3 onwards)
- Hindi text (needs a bundled Devanagari font; planned for Phase 5)

## Get the APK (from a phone, no PC)

1. Upload all these files to your GitHub repository (keep the same folders).
   The `.github/workflows/build-apk.yml` file must stay at that exact path.
2. Open the repo > Actions tab > "Build Android APK" > Run workflow (it also runs on every push to main/master).
3. When it turns green, open the run > Artifacts > download `AloneMan-debug-apk` (a zip) > extract > install the APK.
   Android will ask you to allow "install unknown apps" for your browser/files app.
4. If the run is red, open the failed step and send the log (or a screenshot) back - that is the real test result.

## Controls (also work on PC for testing)

| Action | Touch | PC |
|---|---|---|
| Move | left joystick | W A S D |
| Sprint | push joystick beyond the ring | Shift |
| Look | drag on the right half | drag with mouse on the right half |
| Jump | JUMP button | tap the JUMP button with the mouse |
| Crouch | CROUCH button (toggle) | mouse click on the button |
| Use | USE button | mouse click on the button |

## Folder map

- `scripts/main.gd` - builds and connects everything
- `scripts/player.gd` - movement, jump, crouch, use
- `scripts/camera_rig.gd` - third-person camera
- `scripts/mobile_controls.gd` - joystick, look area, buttons (size/opacity are exported variables)
- `scripts/hud.gd` - HUD
- `scripts/test_world.gd` - temporary test arena (replaced in Phase 2)
- `export_presets.cfg` - Android export settings (arm64 only, package `com.aloneman.survival`)
