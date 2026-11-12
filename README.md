# Fishus Maximus

A cozy fishing game set on the Bay of Naples in AD 72, made for Steam (Windows, Mac, Linux and Steam Deck), in 14 languages.

Fish from a small boat with a line, traps, a cast net, or a trident by lamplight. The Romans were mad about fish, so the catch is only the start: the best fish are kept alive in the estate's fish pond for rich villa owners, the town's orders pay far better than the market, and everything else goes into your uncle's garum works to ferment. Fish by hand, or leave the boat fishing on its own in a strip along the edge of the desktop.

*Cast n Chill, with a Roman fish pond.*

## Playing it

The game is made with Godot 4.7. With `GODOT` standing for the Godot executable:

```
GODOT --path game
```

Add `-- --demo-state` for a game some way in, or `-- --max-state` for one with everything open. Neither is saved.

## The project

| Folder | What is in it |
|---|---|
| `game/` | The Godot project: scenes, GDScript, art, sound and the data files |
| `game/data/` | Every number and name in the game, from `fish.json` to `balance.json` |
| `game/tests/` | Automated checks |
| `docs/` | The build plan, the trailer plan, the Steam setup and publishing, and the release builds |
| `tools/` | Scripts for art, sound, translations, exporting and publishing |
| `store/`, `marketing/` | The Steam page, the achievements and the pictures |
| `builds/` | Exported builds (not kept in git) |

The whole game is described in [Overview.md](Overview.md), and the detailed rules in [Mechanics.md](Mechanics.md).

## Checking changes

```
GODOT --headless --path game -- --run-tests
```

It has to print `ALL TESTS PASSED`. After adding or changing any picture or sound, run `GODOT --headless --path game --import`, or the game keeps using the old file.

## Builds

`python tools/export.py` exports Windows, Mac and Linux into `builds/`, each with its credits file beside it. `python tools/steam/publish.py playtest` builds and uploads to Steam; see [Steam publishing](docs/Steam-publishing.md) for the one-time setup.

Pushing a version tag such as `v1.0.0` makes GitHub test the game, build it for Windows, Mac and Linux, sign and notarize the Mac app and attach every build to a release; see [Release builds](docs/Release-builds.md).

## Art and sound

Scenes are pixel art at 480 by 270, painted with PixelLab (what each picture cost is in `tools/art/ledger.csv`) and finished by the Python scripts in `tools/art/`. Every sound is a real recording, and the music is a harp pack. Everything shipped with the game is credited in [CREDITS.md](CREDITS.md).
