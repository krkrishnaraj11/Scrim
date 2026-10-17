# Scrim

A tiny macOS menu bar utility that turns off your Mac's built-in display when
a real external monitor is connected, and turns it back on automatically if
the external monitor goes away. Useful if you run your laptop closed or
side-by-side with an external monitor and don't want the internal panel
burning power or showing a mirrored/extended desktop you don't need.

- Lives in the menu bar only (no Dock icon)
- Auto-disables the internal display when an external monitor connects
  (toggle off if you'd rather do it manually)
- Manual "turn off now / back on" control, with a safety check that refuses
  to black out the internal display if no external monitor is active
- Handles sleep/wake and external-monitor-unplugged-during-sleep correctly
- Optional launch at login

## How it works

macOS has no public API to disable a specific display outright — only to
change its mode. Scrim uses a private WindowServer symbol
(`CGSConfigureDisplayEnabled`, see `Sources/Scrim/CGSPrivate.swift`) that
several other display-management tools rely on for the same reason. This is
undocumented and could change in a future macOS release.

## Installing

Download the latest `Scrim.app.zip` from the
[Releases](../../releases) page, unzip, and move `Scrim.app` to
`/Applications`.

### First launch

This build is signed ad hoc, not notarized by Apple (notarization requires a
paid Apple Developer Program membership). On first launch, macOS Gatekeeper
will refuse to open it. To allow it:

- **macOS Sequoia (15) and later:** open **System Settings → Privacy &
  Security**, scroll to the bottom, and click **Open Anyway** next to Scrim
  (you'll need to try opening the app once first so it shows up there).
- **macOS Sonoma (14) and earlier:** right-click (or Control-click)
  `Scrim.app` and choose **Open**, then confirm in the dialog.

Alternatively, from Terminal:

```sh
xattr -d com.apple.quarantine /Applications/Scrim.app
```

## Building from source

Requires Xcode Command Line Tools (Swift 5.9+) and macOS 13+.

```sh
./Scripts/build-app.sh
open dist/Scrim.app
```

## License

MIT — see [LICENSE](LICENSE).
