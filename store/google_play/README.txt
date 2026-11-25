FISHUS MAXIMUS: GOOGLE PLAY STORE LISTING PICTURES

The pictures the Google Play store listing needs, ready to upload in Play Console (play.google.com/console). Open the
app, then Store presence > Main store listing > Graphics.

The pictures are made by python tools/phone/make_store_art.py, which has the game render each scene with its phone
interface (--phone) at the store's exact size, so they always match the game. Fish swim in and out of view, so the
game waits for a moment when they are apart and leaves out any fish cut off by the picture's edge, behind a button or
crossing another. Run it again after the art or the interface changes, then look at every picture. Like the Steam
screenshots, they carry no captions. The scene is drawn at a whole number of screen pixels to the game pixel in every
picture (4 on the phone and the 7-inch tablet, 5 on the 10-inch tablet), and nothing is resized with smoothing.


APP ICON

icon_512.png   512x512, 32-bit PNG, every pixel opaque.
               The game's gilt-head bream leaping clear of the sea at sunset: the icon's 64 pixel tile without its
               rounded corners and dark rim (tools/art/make_icon.py's Android layers laid together), enlarged eight
               times, nearest neighbour. It fills the whole square, because Google rounds the corners and adds the
               shadow itself.
               Meets: 512x512 32-bit PNG, at most 1024 KB (this one is 6 KB).


FEATURE GRAPHIC

feature_graphic_1024x500.png   1024x500, 24-bit PNG, no alpha.
               The harbour at sunset, the boat with the dog in its bow in the middle of the bay and the harbour house
               and lighthouse at the left, with the game's logo over the sky. The harbour is rendered at one screen
               pixel to the game pixel and enlarged twice, and the logo is enlarged by the same two, so the two share
               one pixel size. No badges and no text but the logo.
               Meets: 1024x500, JPEG or 24-bit PNG without alpha.


PHONE SCREENSHOTS (phone_screenshots/, all 1920x1080 landscape, 24-bit PNG)

Upload them in this order; the first three show first on the listing.

01_the_harbour_at_sunset.png             The harbour at sunset in spring: the fishing boat with the dog in its bow, the
                                         harbour house and lighthouse, a shoal under the boat, and the phone interface
                                         (the boat's panel, the logbook, settings and menu, the rowing arrows and the
                                         ways of fishing along the bottom).
02_a_dentex_on_the_line.png              The trailer's first cast off the rocky shore on a summer morning: a dentex
                                         leaps from the water on the line, the dog watching from the skiff, the sea
                                         cave and the watchtower behind.
03_the_catch_banner.png                  The catch banner hung out over the open bay at golden hour in autumn: a
                                         dolphinfish, its weight and grade, new in the logbook.
04_the_harbour_town.png                  The harbour town's covered street: the fish market, the netmaker, the
                                         boatwright and the goldsmith, the harbour board, and townsfolk standing in the
                                         street clear of the buttons.
05_the_pond_at_home.png                  The estate's pond in the late afternoon: the villa, the garum works and
                                         Vesuvius behind, and five of the pond's fish (a moray among them) swimming
                                         apart over the rocks and weed.
06_capri_under_sail.png                  The sailing boat at noon under Capri's natural arch, the town on the hill
                                         behind.
07_rain_on_lake_lucrine.png              Rain on the Lucrine Lake in autumn: the sailing boat by the oyster posts and
                                         the fishermen's cottages, two fish under it.
08_northern_lights_over_the_harbour.png  The harbour at night under the northern lights, the big boat's lantern lit,
                                         the moon's path on the water and three fish below. The one picture without
                                         the interface, which would sit over the lights.

Meets: 2 to 8 phone screenshots, JPEG or 24-bit PNG without alpha, each side 320 to 3,840 px, 16:9. A game needs at
least three 16:9 landscape screenshots of at least 1920x1080 to be shown in Google Play's game recommendations; all
eight qualify.


TABLET SCREENSHOTS

tablet_7_inch_screenshots/    1920x1080 landscape (16:9), 24-bit PNG
tablet_10_inch_screenshots/   2560x1440 landscape (16:9), 24-bit PNG

Each folder holds the phone's eight scenes in the same order, taken at that window size with the phone interface, so
the layout is the one a tablet of that shape gets. The 7-inch pictures have the phone's size and layout.

01_the_harbour_at_sunset.png
02_a_dentex_on_the_line.png
03_the_catch_banner.png
04_the_harbour_town.png
05_the_pond_at_home.png                  On the 10-inch tablet the pond keeps six of its fish, since its wider view
                                         shows more of the pond and the fish in view are kept apart.
06_capri_under_sail.png
07_rain_on_lake_lucrine.png
08_northern_lights_over_the_harbour.png

Meets: up to 8 screenshots for each tablet size, JPEG or 24-bit PNG without alpha, each side 320 to 3,840 px, the long
side at most 2.3 times the short one. They are 16:9, as Google's large-screen guidance asks for a game to be featured
on tablets.


NOT MADE HERE

- The listing's text (app name, short description and full description): listing.txt in this folder.
- The answers for Play Console's App content forms (content rating, data safety, ads, target audience and the rest):
  app_content_answers.txt in this folder.
- A promo video, optional, given as a YouTube link.
- Chromebook and Android XR screenshots, optional.
- The privacy policy page itself, whose address app_content_answers.txt asks for.
