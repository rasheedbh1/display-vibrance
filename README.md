# Display Vibrance

Native macOS menu-bar controls for saturation, adaptive vibrance, and gamma.
Built to push the colors on an MSI monitor past what macOS offers.

## Build

Requires macOS 14 or later and the Swift 6 toolchain (Xcode or Command Line Tools).

```sh
./build-app.sh
```

This builds a release binary, wraps it in `.build/Display Vibrance.app`, ad-hoc
signs it, and writes `.build/Display-Vibrance.zip`.

## Install

1. Move **Display Vibrance.app** to `/Applications` or `~/Applications`.
2. Control-click it and choose **Open** on first launch. The app is ad-hoc
   signed, so Gatekeeper asks once per machine.
3. The app has no Dock icon. Use the half-filled-circle icon in the menu bar.

On launch, at login, and when a display reconnects, the app reapplies your saved
settings. Neutral settings (saturation 100, vibrance 0, gamma 100) leave the
display untouched.

## Reset

The app backs up the active display profile before its first change. Use
**Reset to Original** (Option-Command-R) at any time. If the app is not running,
restore the MSI profile in System Settings > Displays > Color profile.

## Notes

HDR and protected video paths may bypass custom ColorSync processing. Saturation
uses the display profile's RGB colorant matrix. Vibrance is a bounded adaptive
contribution, which avoids the clipping a full saturation boost causes.
