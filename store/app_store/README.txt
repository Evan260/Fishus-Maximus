FISHUS MAXIMUS: APP STORE PICTURES

The pictures the App Store listing needs. Screenshots are uploaded in App Store Connect (appstoreconnect.apple.com):
Apps, the game, the version being prepared, then Previews and Screenshots, with one tab per display size.

The pictures are made by python tools/phone/make_store_art.py, which has the game render each scene with its phone
interface (--phone) at the store's exact size, so they always match the game. Fish swim in and out of view, so the
game waits for a moment when they are apart and leaves out any fish cut off by the picture's edge, behind a button or
crossing another. Run it again after the art or the interface changes, then look at every picture. Like the Steam
screenshots, they carry no captions. The scene is drawn at a whole number of screen pixels to the game pixel in every
picture (4 on the iPhone, 5 on the iPad), and nothing is resized with smoothing.


APP ICON

icon_1024.png   1024x1024 PNG, no alpha channel, square corners.
                The game's gilt-head bream leaping clear of the sea at sunset: the icon's 64 pixel tile without its
                rounded corners and dark rim, enlarged sixteen times, nearest neighbour. Apple rounds the corners
                itself.
                Meets: the App Store icon, 1024x1024, no transparency and no alpha channel, no rounded corners.
                App Store Connect takes this icon from the build rather than from an upload, so it goes into Godot's
                iOS export preset, in its Icons section (the 1024x1024 App Store icon).


IPHONE SCREENSHOTS (iphone_6.9_inch_screenshots/, all 2868x1320 landscape, PNG without alpha)

01_the_harbour_at_sunset.png             The harbour at sunset in spring: the fishing boat with the dog in its bow, the
                                         harbour house and lighthouse, the cape and the villa across the bay, and the
                                         phone interface.
02_a_dentex_on_the_line.png              The trailer's first cast off the rocky shore on a summer morning: a dentex
                                         leaps from the water on the line, the dog watching from the skiff.
03_the_catch_banner.png                  The catch banner hung out over the open bay at golden hour in autumn: a
                                         dolphinfish, its weight and grade, new in the logbook.
04_the_harbour_town.png                  The harbour town's covered street: the fish market, the netmaker, the
                                         boatwright and the goldsmith, the harbour board, and townsfolk standing in the
                                         street clear of the buttons.
05_the_pond_at_home.png                  The estate's pond in the late afternoon, the villa and the garum works behind.
                                         The iPhone's wide screen shows nearly the whole pond, so it keeps five of its
                                         fish, all in view and apart.
06_capri_under_sail.png                  The sailing boat at noon under Capri's natural arch.
07_rain_on_lake_lucrine.png              Rain on the Lucrine Lake in autumn: the sailing boat by the oyster posts.
08_northern_lights_over_the_harbour.png  The harbour at night under the northern lights, the big boat's lantern lit.
                                         The one picture without the interface, which would sit over the lights.

Meets: the 6.9-inch iPhone display size, which takes 2868x1320 in landscape (or 2796x1290 or 2736x1260); 1 to 10
screenshots, PNG or JPEG without alpha. Apple scales these down for the smaller iPhones, so this one size covers them.


IPAD SCREENSHOTS (ipad_13_inch_screenshots/, all 2752x2064 landscape, PNG without alpha)

01_the_harbour_at_sunset.png             The harbour at sunset, with the seabed under the boat.
02_a_dentex_on_the_line.png              A dentex leaping from the water off the rocky shore.
03_the_harbour_town.png                  The harbour town's covered street, its roof beams over the stalls.
04_the_pond_at_home.png                  The estate's pond in the late afternoon, five of its fish swimming apart.
05_rain_on_lake_lucrine.png              Rain on the Lucrine Lake, two fish under the boat and the lake's floor below.
06_northern_lights_over_the_harbour.png  The harbour at night under the northern lights, without the interface.

An iPad's squarer screen shows the coast deeper below the waterline and crops the street's sides, as the game does for
any window near 4:3. Capri is left out here: under it the iPad shows only deep, empty water.

Meets: the 13-inch iPad display size, which takes 2752x2064 in landscape (or 2732x2048); required when the game runs
on iPad; 1 to 10 screenshots, PNG or JPEG without alpha. Apple scales these down for the smaller iPads.


NOT MADE HERE

- App previews, the optional videos of 15 to 30 seconds for each display size.
- The listing's text: name (30 characters), subtitle (30), promotional text (170), description (4,000) and keywords
  (100). store/google_play/listing.txt is a starting point: it avoids "demo" and "trial", so it reads right on the
  App Store too. store/google_play/app_content_answers.txt has the answers about data and ads that the App Store's
  privacy questions also ask.
- A support link and a privacy policy link, and the age rating questionnaire, which are forms in App Store Connect.
