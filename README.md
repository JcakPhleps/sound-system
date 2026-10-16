# Conductor Pro

A small native macOS app to control the audio going to the powered speakers in my
room. Because the speakers just plug into the Mac (aux / USB DAC), the app really
controls **the Mac's own audio**: where it goes, how loud it is, what's playing, and
(soon) a system-wide equalizer.

Native SwiftUI, personal use, not sandboxed.

## Features (Phase 1)

- **Now Playing + transport** — play/pause, next, previous for Apple Music, Spotify,
  or "System" (synthesized media keys).
- **Source picker** — choose which app the controls target.
- **Output switching** — pick the output device (built-in, aux, USB DAC…); the list
  updates live as devices are plugged/unplugged and badges USB devices.
- **Volume + mute** — a real output-volume slider that reflects hardware/menu-bar
  changes.
- **Equalizer (UI only for now)** — 10-band graphic EQ with presets. The controls are
  live; the system-wide audio processing lands in Phase 2.
- **Permissions panel** — shows Automation (Apple Events) status for Music/Spotify.

## Phase 2 (planned)

True **system-wide EQ** via a Core Audio **process tap** + private aggregate device,
processing all system audio through an equalizer and out to the chosen device. No
third-party audio driver required.

## Build & run

Requirements: macOS 14+, Xcode installed, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

Requires **Xcode 27+** (for the Liquid Glass `.icon` and `.glassEffect` APIs; the
app runs on macOS "Golden Gate"/27).

```sh
xcodegen generate          # regenerate SoundSystem.xcodeproj from project.yml
open SoundSystem.xcodeproj  # then Run, or point at your Xcode 27:
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  xcodebuild -project SoundSystem.xcodeproj -scheme SoundSystem -configuration Debug build
```

The EQ engine has a headless check: `"Conductor Pro" --eq-selftest`.

`project.yml` is the source of truth; the generated `.xcodeproj` is git-ignored.

### Stable permissions across rebuilds (optional)

macOS keys Automation/TCC grants to the app's code signature. Ad-hoc signing changes
the signature on every build, which can re-trigger permission prompts. To avoid that,
create a self-signed **Development** certificate in Keychain Access
(*Certificate Assistant → Create a Certificate…*, type *Code Signing*) and set
`CODE_SIGN_IDENTITY` in `project.yml` to its name.

## Layout

```
project.yml                     XcodeGen spec (source of truth)
Support/                        Info.plist, entitlements (sandbox off)
Sources/SoundSystem/
  App/          app entry + delegate (owns controllers, lifecycle)
  CoreAudio/    HAL wrapper + AudioDevice model
  Controllers/  AudioDeviceManager, VolumeController, TransportController,
                EQController, PermissionsManager  (@MainActor @Observable)
  Media/        AppleScript bridge, media-key poster, PlaybackSource
  Views/        SwiftUI views
```
