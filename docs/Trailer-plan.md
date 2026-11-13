# Fishus Maximus trailer

The Steam trailer is 78 seconds long. It tells one story: you inherit your uncle's old boat on the Bay of Naples, land your first fish, fish your way round the bay, and come home to a town, a bigger boat, a dog and a pond of your own, with the boat fishing on along the bottom of your screen. It is made the same way as the Mosaicus Maximus and Farmus Maximus trailers: every shot is the game playing itself in movie mode, and an edit scene cuts the shots together on the beat of the game's own music.

## The story

1. **The place and the time.** A black card: "The Bay of Naples, AD 72."
2. **The inheritance.** The harbour at first light: the skiff waits by the jetty with the dog aboard, then rows out into the bay. A card: "Your uncle has left you his old boat."
3. **The first fish.** Off the rocky shore the rod swings back and the line is cast, a dentex swims in from past the edge of the view, comes up to the bait, nibbles and takes it, and the fight runs with the fish leaping clear of the water. It comes up onto the catch banner, new to the logbook, all in one unbroken take.
4. **The bay.** A card: "Sixty kinds of fish, all ones the Romans knew." The rocky shore, the caves of Capri under sail and Misenum at dusk, a slow pass over the sunken fishing boat on the open bay's seabed with fish swimming by, then deep water off Misenum at night under the northern lights, the big boat's lantern lit as the line goes out.
5. **The collection.** The logbook's pages turn from place to place, every fish drawn with its best weight.
6. **The town.** A card: "Sell your catch in town, and save for a bigger boat." The covered street with its townsfolk, the boatwright where the big boat is bought, and the big boat under sail in the golden hour, its sail full and its flag flying.
7. **The dog.** The dog in the boat is petted, wags and sends up hearts, shown twice as large.
8. **Home.** A card: "Keep the best alive in your own pond." The estate's pond full of fish, fed, with the sea washing up the beach beyond.
9. **The desktop.** A card: "Or let him fish on his own, along the bottom of your screen." The boat fishing on its own in the strip along the bottom of a desktop.
10. **The end card.** The harbour at sunset, the logo and "Wishlist now on Steam".

## Cut list

One beat is 0.857 seconds of "Adventure Begins" from the game's soundtrack, which runs 82 seconds, and every cut lands on a beat.

| # | Shot or card | Beats |
|---|---|---|
| 1 | Card: The Bay of Naples, AD 72. | 4 |
| 2 | `dawn`: the harbour at first light, fading in, the skiff rowing out | 5 |
| 3 | Card: Your uncle has left you his old boat. | 3 |
| 4 | `cast`: the cast, the dentex swimming in to the bait, the bite, the fight with a leap, and the catch banner, in one take | 17 |
| 5 | Card: Sixty kinds of fish, all ones the Romans knew. | 3 |
| 6 | `rocky`, `capri`, `misenum`: three places along the bay | 3 each |
| 7 | `wreck`: the view passing over the sunken boat in the open bay as fish swim by | 4 |
| 8 | `night`: off Misenum under the northern lights, the line cast into the dark | 5 |
| 9 | `logbook`: the pages turning | 4 |
| 10 | Card: Sell your catch in town, and save for a bigger boat. | 3 |
| 11 | `town`: the street | 3 |
| 12 | `boatwright`: the big boat bought | 3 |
| 13 | `sail`: the big boat under sail | 4 |
| 14 | `dog`: the dog petted, twice as large | 3 |
| 15 | Card: Keep the best alive in your own pond. | 3 |
| 16 | `pond`: the estate's pond, fed | 4 |
| 17 | Card: Or let him fish on his own, along the bottom of your screen. | 3 |
| 18 | `strip`: the strip over a desktop | 5 |
| 19 | `endcard`: the harbour at sunset, the logo and the wishlist scroll | 6 |

## How it is made

- `python tools/trailer/make_trailer.py` records every shot that is not recorded yet, then renders the trailer. `shots NAME...` records shots again, and `render` renders from the recorded shots, or from a given second into a preview.
- `game/tools/trailer/shots.gd` scripts the shots. The game starts it with `--trailer-shot=NAME`. Each makes up a game with `Game.demo_state()` or `Game.max_state()` (the late game's logbook filled and its pond stocked), never saved, with the seed fixed at 7, the game's music muted and no achievement told of, then opens the screen with the game's own flags and plays it: rowing as a held key would, the first cast by the game's own demo cast with a dentex brought in from past the right of the view by `Swimmers.bring_in` and sent to the bait (with the best rod and a tired fish, so the whole catch fits one take with the fish reeled in at the game's own pace), the view carried slowly over the open bay's wreck, the logbook turned, and a drawn pointer that clicks the boatwright's tile. The real mouse is shut out.
- `game/tools/trailer/edit.gd` is the edit: the cut list, the cards in the game's own text font at twice its size, the strip laid over `marketing/desktop.png` above its taskbar, the end card and the music. Each shot's own sounds play under the music; the dog's bark and yips and the late afternoon's cicadas are left out of the recordings, with the gulls kept softly where nothing else would play, so the end card at sunset has the calm harbour under it.
- The shots are recorded at 1920 by 1080 and 30 frames a second, four screen pixels to the game pixel, into `marketing/recordings/content/trailer_shots/`, which git ignores. The strip is recorded at its own size, 1920 by 270 at three screen pixels to the game pixel, on its see-through background.
- The finished trailer, `steam_trailer.avi` and an `.mp4` copy with its sound brought to -16 LUFS, goes to `marketing/recordings/videos/steam_trailer/`, beside its `title.txt`, `description.txt` and `thumbnail.png`, a frame of the end card. Git ignores it for its size.
- `marketing/desktop.png` is Farmus Maximus's desktop screenshot with the Fishus Maximus icon in place of the Farmus one, on the desktop and the taskbar.
- The logo and the end card's scroll are drawn by `tools/trailer/make_logo.py`.
- The music is "Adventure Begins" from Bard's Tales: Peaceful Harp Music Pack by Amos Cháb (Mythago Music), the game's own soundtrack, which asks for no credit; the description credits it anyway. Before uploading, confirm with Mythago Music that the free edition may be used in a trailer, as for the other two games.

## The shorts

Seven vertical shorts for YouTube Shorts, Instagram Reels and TikTok, made the same way as the trailer and laid out like Mosaicus Maximus's and Farmus Maximus's: 1080 by 1920 at 30 frames a second, 15 to 31 seconds, a caption from the very first frame in the game's text font at three times its size, outlined in ink, and the same end card as the trailer, the logo and "Wishlist now on Steam" over the harbour at sunset. The captions sit below the top bar of a phone's video apps and the end card above their captions at the bottom. Each is `python tools/trailer/make_trailer.py --cut=NAME`.

| Cut | Hook | Shots |
|---|---|---|
| `legend` | "something huge is under my boat": the Senator comes out of the dark at night off Misenum, is fought up and hangs on the catch banner | `legend` |
| `first_vs_last` | "my first fishing boat": the skiff, the fishing boat, the sailing boat and the big boat | `boat_skiff`, `boat_fishing`, `boat_sailing`, `boat_big` |
| `cozy_sounds` | "turn your sound on": no music, the harbour at dawn, a cast and its reel, rain on the rocky shore, the pond fed and the harbour at night | `dawn`, `cast`, `rain`, `pond`, `night_harbour` |
| `pet_the_dog` | "yes, you can pet the dog": the hound, the mastiff, the sighthound and the sheepdog petted in the bow, shown twice as large; the lapdog sits down out of sight behind the fishing boat's side | `pet_hound`, `pet_molossian`, `pet_sighthound`, `pet_sheepdog` |
| `on_my_desktop` | "I put a Roman fishing boat on my desktop": the strip over the middle of `marketing/desktop.png`, the boat fishing on its own and the dog asleep | `desk`, `idle`, `idle_dog` |
| `shipwreck` | "what's under my boat?": the view goes down from the boat to the old wreck off the rocky shore, and a conger swims out | `wreck_dive` |
| `fish_by_name` | "Roman fish came when called by name": the bell is rung at the pond and Hortensia, Aurata and Lupus come to the front | `pond_bell` |

- The shots are recorded at six screen pixels to the game pixel, a view 180 game pixels wide and 320 tall. The game would draw a window of a phone's shape at two, so `shots.gd` fits the view itself (`TALL_ZOOM`) and keeps the boat in the middle of it.
- `dawn`, `cast`, `pond` and `endcard` are the trailer's own shots recorded again in the tall frame. The strip is recorded 1080 pixels wide at three screen pixels to the game pixel, over the middle of the desktop enlarged to fill the frame.
- Every short but `cozy_sounds` plays "Adventure Begins" under the shots' own sounds. The dog's bark and yips and the cicadas are left out, as in the trailer.
- Each finished short goes to `marketing/recordings/videos/short_<name>/` with an `.mp4` copy, beside its `title.txt`, `description.txt` and `thumbnail.png`, a frame of the short with its caption.
