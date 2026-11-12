# Fishus Maximus: Publishing to Steam

How builds get onto Steam and to players. Once the steps below are done, every update is one command, and everyone with the game on Steam receives it automatically the next time their Steam client updates.

## What is already set up

- `tools/export.py` exports the game for Windows, macOS and Linux into `builds/<platform>/`, each with `Credits and licences.txt` beside it, and the Windows one with the launcher that opens a game with everything unlocked. `python tools/export.py` builds all three; `python tools/export.py windows` builds one. The macOS build is Godot's `.zip` with the app inside, unsigned, and it is also copied to `C:\Users\evand\MacShare\Fishus Maximus\` for testing on the Mac.
- `tools/steam/publish.py` exports the game for each platform with a depot through `tools/export.py`, then hands over to WSL (the Linux that runs inside Windows), which lays out the builds, signs and notarizes the Mac app, and uploads everything. It leaves the everything-unlocked launcher out of every depot, so players never get it; it stays in local builds and the GitHub release.
- The upload runs in WSL because a Mac app copied through Windows loses its file permissions and will not open, and the Linux game needs its "executable" permission too. `tools/steam/wsl_build.sh` does that half.
- `tools/steam/wsl_setup.sh` installs Valve's Linux steamcmd and rcodesign (the tool that signs and notarizes a Mac app without a Mac) into `~/fishus-steam` inside WSL. This has already been run on this computer.
- `tools/steam/apple_setup.sh` makes the Apple credentials; `tools/steam/macos_entitlements.plist` gives the Mac app the two permissions the Steam overlay needs.
- `tools/steam/steam.json` holds the Steam account name and the app and depot numbers. They are all zero until the steps below give you those numbers; a depot left at 0 is skipped.
- GodotSteam is in `game/addons/godotsteam` and goes out with every build; `docs/Steam-setup.md` says how the game uses it and how to test with Valve's test app.

The Windows build uses a trimmed Godot engine, `tools/engine/slim.windows.template_release.x86_64.exe`, copied from Farmus Maximus. It is kept in Git LFS, so a fresh clone and the GitHub release builds (`Release-builds.md`) use it; copy it again after every Godot update and commit it; its build settings are in `tools/engine/slim_profile.py`. The macOS and Linux builds use Godot's standard export templates.

## One-time setup on this computer

If WSL is ever reinstalled, open PowerShell in the project folder and run:

```
wsl -u root -- bash tools/steam/wsl_setup.sh
```

It installs steamcmd and rcodesign inside WSL and prints the rcodesign version when it is done.

## One-time setup on Steamworks

These steps need you, because they involve your Steam account, payment and tax details.

1. **Join Steamworks.** Sign up at partner.steamgames.com, pay the Steam Direct fee (about \$140 CAD per game, paid back once the game earns about \$1,400 CAD), and fill in the tax and bank forms. Valve checks these, which can take from a few days to a couple of weeks.
2. **Create the app.** Steamworks gives the game an **App ID**, for example 3456780. Under App Admin, SteamPipe, Depots, it also creates a **depot**, usually numbered one higher, for example 3456781. Set that depot's operating system to Windows, then add two more depots, one set to macOS and one to Linux + SteamOS.
3. **Tell Steam how to start the game.** Under Installation, General, add three launch options:
   - executable `Fishus Maximus.exe`, operating system Windows
   - executable `Fishus Maximus.app`, operating system macOS
   - executable `Fishus Maximus.x86_64`, operating system Linux + SteamOS
4. **Say the Mac app is notarized.** Under Installation, General (or the store page's Platforms section), tick **App Bundles Are Notarized**. Steam has required notarized Mac games since 2019.
5. **Add a test branch.** Under SteamPipe, Builds, create a branch named `testing`. No password is needed.
6. **Publish the settings.** Steamworks changes only apply after you press Publish on the Publish tab.
7. **Create the Playtest.** On the game's Steamworks page, open Playtest and create one. This makes a separate app, "Fishus Maximus Playtest", with its own App ID. Repeat steps 2 to 6 for it, adding Mac and Linux depots only if Mac and Linux testers are wanted.
8. **Fill in the numbers.** Put the account name and the numbers into `tools/steam/steam.json`:
   - `account`: the Steam account that uploads builds. Valve recommends a separate Steam account that has only the permission to upload builds, so your own account is never used by a script.
   - `targets.playtest`: the Playtest's App ID and its depots (`windows`, and `macos` and `linux` if it has them).
   - `targets.game`: the main game's App ID and its three depots.
9. **Log in to steamcmd once.** In PowerShell, run:

   ```
   wsl ~/fishus-steam/steamcmd/steamcmd.sh +login YOUR_ACCOUNT +quit
   ```

   Type the password, then the Steam Guard code from the email or the Steam phone app. steamcmd remembers the login, so the publish script never needs the password.

## Signing the Mac app

Steam needs the Mac app signed with a Developer ID and notarized by Apple. The builds made here leave it unsigned, so there are two ways to do that.

**On the Mac.** The Developer ID's private key is in the Mac's keychain, so the app can be signed, notarized and stapled there, with `tools/steam/macos_entitlements.plist` as its entitlements. This suits testing and a first upload made by hand.

**In WSL, for the publish script.** `publish.py` signs and notarizes the app itself when WSL has the credentials in `~/fishus-steam/apple`, and refuses to upload an unsigned Mac app. To give it them:

1. On the Mac, open Keychain Access, find the **Developer ID Application** certificate, and export it with its private key as `developer_id.p12`, choosing a password.
2. Copy the file into WSL and store the password next to it:

   ```
   wsl mkdir -p ~/fishus-steam/apple
   wsl cp /mnt/c/Users/evand/Downloads/developer_id.p12 ~/fishus-steam/apple/
   wsl sh -c "printf '%s' 'THE_PASSWORD' > ~/fishus-steam/apple/p12_password && chmod 600 ~/fishus-steam/apple/*"
   ```

3. **Make the notarization key.** At appstoreconnect.apple.com, go to Users and Access, Integrations, App Store Connect API, Team Keys, and generate a key with the **Developer** role. Note the **Issuer ID** at the top of the page and the key's **Key ID**, and download the `.p8` file (Apple only lets you download it once).
4. **Store the key:**

   ```
   wsl bash tools/steam/apple_setup.sh api-key ISSUER_ID KEY_ID "C:\Users\evand\Downloads\AuthKey_KEYID.p8"
   ```

   Then delete the `.p8` and `.p12` files from Downloads; WSL keeps what it needs in `~/fishus-steam/apple`.

If Farmus Maximus or Mosaicus Maximus already has these credentials in WSL, the same ones work here: `wsl cp -r ~/farmus-steam/apple ~/fishus-steam/`. Without a Developer ID certificate to export, `apple_setup.sh csr` and `apple_setup.sh p12` make a new one from a certificate request instead, as Farmus Maximus's `docs/Steam-publishing.md` describes; only the Apple Developer account's Account Holder can do that.

## Giving a tester access

1. In Steamworks, open the Playtest app and request Steam keys (a handful is plenty).
2. Send one key to the tester. They redeem it in Steam under Games, Activate a Product on Steam, and the Playtest appears in their library.
3. They right-click it, choose Properties, Betas, and pick `testing`. They only do this once; from then on Steam keeps them on the newest test build.

## Sending an update

Ask Claude to "push an update to the playtest", or run:

```
python tools/steam/publish.py playtest --note "Calmer gulls"
```

The script builds the game for every platform with a depot, signs and notarizes the Mac app (Apple's check usually takes a few minutes), uploads it and makes it live on the `testing` branch. Testers get it the next time Steam updates, usually within minutes when Steam is open. The note and the git commit appear next to the build in Steamworks, under SteamPipe, Builds.

`--dry-run` builds every platform, signs the Mac app if the Apple credentials exist, and lays everything out in `~/fishus-steam` inside WSL without notarizing or uploading, to check that everything is in order. Before the numbers are in `steam.json`, a dry run builds all three platforms.

## The default branch and release

Steam only lets a script make a build live on a branch such as `testing`. For the default branch, the one every buyer gets, go to SteamPipe, Builds in Steamworks and set the build live there yourself. This is Valve's safeguard against a script releasing a broken build to everyone. When the game launches, the same command uploads with `game` instead of `playtest`, and you set each release live on the default branch by hand.
