# Fishus Maximus: Steam Setup

What has to happen on Steam's side before launch. The game already does its part: it records achievements in the save, and sends them to Steam whenever Steam is present.

## 1. Connect the game to Steam

GodotSteam 4.24 (the GDExtension build, with Steamworks SDK 1.65) is in `game/addons/godotsteam`, with its libraries for 64-bit Windows, macOS and Linux. Every export carries them: beside the exe on Windows and Linux, and inside the app on macOS. `game/scripts/autoload/awards.gd` starts Steam with `steamInitEx()`, runs Steam's callbacks every frame and sends achievements; when the Steam client is not running, it prints one line saying so and the achievements stay in the save. The game needs nothing else from Steam.

1. Create the app in Steamworks and note its App ID.
2. To try Steam outside Steam before then, put a file named `steam_appid.txt` holding `480` (Valve's Spacewar test app) next to the game's executable, or in `game/` when running from the editor, and start the Steam client. `steam_appid.txt` is ignored by git and never goes into a build, because Steam gives the real App ID to a game it launches. Achievements sent under 480 land on Spacewar, not on Fishus Maximus, so use it only to see that Steam starts.
3. When the real App ID exists, it goes into `tools/steam/steam.json`; `steam_appid.txt` can hold it instead of 480 for local tests.

Uploading builds to Steam is in `docs/Steam-publishing.md`.

To update GodotSteam, download the newest GDExtension release (the tag ending in `-gde`) from codeberg.org/godotsteam/godotsteam/releases, replace the `win64`, `osx` and `linux64` folders and `license.md`, and change the version in `game/data/credits.json`. The `godotsteam.gdextension` here lists only those three platforms.

## 2. The store page

Everything the store page needs is in `store/steam_page`: the capsules, the library art, the page background, the icons, the thirteen screenshots and the text (the short description, About This Game, tags, languages, system requirements and the AI content disclosure). Its `README.txt` says which file goes in which Steamworks slot, and lists what is still to decide, such as the price in CAD.

`python tools/steam/make_store_art.py` makes the pictures from the game itself: the capsules and library hero are scenes the game renders, enlarged by whole steps, with the logo over them; the page background is the night off Misenum; the screenshots are moments of the recorded trailer shots. It writes only to `store/steam_page`, rendering the pieces it crops or combines into a temporary folder that it removes afterwards. Run it again after the art changes. The text files are written by hand.

## 3. Achievements

Enter each of these in Steamworks under Stats and Achievements, with exactly this API name. The list comes from `game/data/achievements.json`; regenerate this table if that list changes. Achievements earned before Steam was connected are sent the next time a screen opens with Steam running.

Each achievement also needs two 64 by 64 icons in Steamworks: one for when it is earned and a grey one for before. They are in `store/achievements`: `<API name>.jpg` is the earned icon and `<API name>_locked.jpg` the grey one, and `sheet.png` shows them all side by side. `python tools/art/make_achievement_icons.py` makes them from the game's own art; when an achievement is added, choose its picture in that script's `ART` list (it refuses to run until every achievement has one) and run it again.

| API name | Name | Description |
|---|---|---|
| `first_fish` | First catch | Land your first fish |
| `chapter_2` | The rocky shore | Open chapter 2 |
| `chapter_3` | The lake and the bay | Open chapter 3 |
| `chapter_4` | Capri | Open chapter 4 |
| `chapter_5` | The deep | Open chapter 5 |
| `legend_carteia_octopus` | The octopus of Carteia | Catch the octopus of Carteia |
| `legend_tiberius_mullet` | Tiberius's mullet | Catch Tiberius's mullet |
| `legend_hortensius_moray` | The moray of Hortensius | Catch the moray of Hortensius |
| `legend_great_tuna` | The great tuna | Catch the great tuna |
| `legend_orata_bream` | Orata's golden bream | Catch Orata's golden bream |
| `legend_claudius_parrotfish` | Claudius's parrotfish | Catch Claudius's parrotfish |
| `legend_misenum_swordfish` | The swordfish of Misenum | Catch the swordfish of Misenum |
| `legend_senator_grouper` | The Senator | Catch the Senator |
| `legend_wreck_conger` | The conger of the wreck | Catch the conger of the wreck |
| `legend_numbing_ray` | The numbing ray | Catch the numbing ray |
| `legend_sleeping_sunfish` | The sleeping sunfish | Catch the sleeping sunfish |
| `legend_neptune_lobster` | Neptune's lobster | Catch Neptune's lobster |
| `all_legends` | Every legend of the bay | Catch all twelve legends |
| `logbook_10` | A fisherman's eye | Catch ten kinds of fish |
| `logbook_25` | Half the bay | Catch twenty-five kinds of fish |
| `logbook_full` | The whole logbook | Catch every ordinary kind of fish |
| `prize_all` | A prize of every kind | Land a prize-grade fish of every ordinary kind |
| `first_pond` | A pond of your own | Dig the estate's fish pond |
| `all_ponds` | The great pond | Widen the pond as far as it goes |
| `all_tanks` | The works restored | Restore all eight garum tanks |
| `sociorum` | Garum sociorum | Bottle the finest garum |
| `pond_show` | Best in show | Win the pond show |
| `neptunalia` | Champion of the Neptunalia | Win the Neptunalia contest |
| `moray_earrings` | Antonia's moray | Keep a named moray wearing earrings |
| `fishing_boat` | A real boat | Buy the fishing boat |
| `sailing_boat` | Under sail | Buy the sailing boat |
| `big_boat` | The big boat | Buy the big boat |
| `orders_10` | Known on the quay | Fill ten orders from the harbour board |
| `orders_50` | The town's fisherman | Fill fifty orders |
| `northern_lights` | Lights in the north | See the northern lights over the bay on a clear night |
| `rich` | A purse of silver | Have a thousand denarii at once |
| `client_cook` | Verecunda's story | Finish everything Verecunda asks of you |
| `client_trimalchio` | Trimalchio's story | Finish everything Trimalchio asks of you |
| `client_umbricius` | Umbricius Scaurus's story | Finish everything Umbricius Scaurus asks of you |
| `client_senator` | Senator Licinius's story | Finish everything Senator Licinius asks of you |
| `client_priest` | Gnaeus Pollius's story | Finish everything Gnaeus Pollius asks of you |
| `client_widow` | Calpurnia's story | Finish everything Calpurnia asks of you |

## 4. Steam Cloud

Use Auto-Cloud; the game needs no code for it. Each game slot is saved as `save_1.json`, `save_2.json` and `save_3.json`, each with up to three rolling backups (`save_1.json.bak1` and so on). Add two root paths per platform, one for the saves and one for their backups:

| Platform | Root | Subdirectory | Pattern |
|---|---|---|---|
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Fishus Maximus` | `save_*.json` |
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Fishus Maximus` | `save_*.json.bak*` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Fishus Maximus` | `save_*.json` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Fishus Maximus` | `save_*.json.bak*` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Fishus Maximus` | `save_*.json` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Fishus Maximus` | `save_*.json.bak*` |

The patterns leave out `save_N.json.tmp`, which only exists for the moment a save is being written. The player's own music (`music/`) and `settings.cfg` stay on each computer. If the save files are ever renamed, these patterns must change with them in `game/scripts/autoload/saves.gd`, or cloud saves quietly stop syncing.

## 5. Rich presence

Steam friends see what the player is doing, such as "Fishing off Capri at dusk" or "Selling the catch in town". `awards.gd` sets the `steam_display` token for the screen (`#Title`, `#Town`, `#Pond`, `#Map`, or `#Fishing_` and the place's id on the coast, with `when` set to `dawn`, `day`, `dusk` or `night`), checks every five seconds and on each change of screen, and hands Steam only what has changed. Without the Steam client running it never calls Steam.

The words are in `tools/steam/rich_presence.vdf`, in all 14 of the game's languages. Upload it once, and again whenever it changes:

1. In Steamworks, open the app's Edit Steamworks Settings, then Community, then Rich Presence.
2. Under Localization, choose the file `tools/steam/rich_presence.vdf` and upload it. Steam reads every language from the one file.
3. Publish the change from the Publish tab.

A new screen or place needs its token in every language of the file; `game/tests/test_steam.gd` fails until it has one.
