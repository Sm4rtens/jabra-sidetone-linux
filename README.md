# jabra-sidetone-linux

Sidetone and busylight for Jabra headsets on Linux.

Jabra's own configuration tool, Jabra Direct, is Windows and macOS only. On
Linux the sidetone setting appears to do nothing, and the busylight never
lights. This is a small pair of shell scripts that fixes both.

## The problem

Sidetone on a Jabra headset is a **call-mode** feature: the headset only mixes
your own voice back into the earcups when it believes a call is in progress.
Crucially, call state travels over **HID**, not over audio. They are two
independent channels:

| Channel | What it does | On Linux |
|---|---|---|
| USB audio | dongle switches the Bluetooth link into bidirectional call mode | happens automatically when an app opens the mic |
| HID telephony | tells the headset "a call is in progress" | **nothing sends this** |

So Linux gets all of the cost of call mode and none of the benefit. The moment
any application opens the microphone, playback drops to speech bandwidth and
sounds thin — but the headset itself is never told a call is happening, so
sidetone never engages and the busylight stays dark.

Enabling sidetone in Jabra Sound+ or Jabra Direct does not help. The setting is
already stored in the headset's firmware, waiting for a signal that never
arrives.

## The fix

Jabra devices expose a standard HID Telephony output report:

```
05 0b  Usage Page (Telephony)      09 05  Usage (Headset)
85 02    Report ID 2
05 08    Usage Page (LED)
09 17      Off-Hook   <- bit 0     "there is a call in progress"
09 1e      Speaker    <- bit 1
09 09      Mute       <- bit 2
09 18      Ring       <- bit 3
09 20      Hold       <- bit 4
09 21      Microphone <- bit 5
09 2a      On-Line    <- bit 6
91 22    Output (Data,Var,Abs)
```

Writing `02 01 00` to the device's `hidraw` node sets the Off-Hook bit — exactly
what Jabra Direct does on Windows when a softphone starts a call. The headset
lights its busylight and turns on sidetone.

`jabra-call` sends those reports. `jabra-call-daemon` watches
PipeWire/PulseAudio and sends them automatically, holding the headset off-hook
for as long as any application has the microphone open.

## Install

```sh
git clone https://github.com/Sm4rtens/jabra-sidetone-linux
cd jabra-sidetone-linux
./install.sh
```

Requires `pactl` (PipeWire or PulseAudio), `jq`, and a systemd user session.
The installer needs `sudo` once, for the udev rule.

Verify:

```sh
jabra-call status     # prints the /dev/hidrawN it found
jabra-call start      # busylight turns red, sidetone comes on
jabra-call stop
```

If `jabra-call` reports the device is not writable, the udev rule has not been
applied yet. `uaccess` is granted when the device is *added*, so replug the
headset or dongle, or run:

```sh
sudo udevadm trigger --action=add --subsystem-match=hidraw
```

## Usage

Once the service is running, nothing else is required — join a call and the
headset goes off-hook on its own.

```
jabra-call start | stop | toggle | mute | unmute | status
```

`toggle` is handy on a hotkey. It pins call state against the daemon until the
set of applications holding the mic next changes, so an override applies to the
call you meant it for and no longer. Outside a call it doubles as a
do-not-disturb light.

The daemon also mirrors mic mute to the headset's mute LED, and hangs up on
`SIGTERM`, so stopping the service or logging out never leaves the headset stuck
off-hook with a red light.

## Known and expected: thin audio during calls

While a call is active, music and system audio sound thin — less bass, more
treble. **This is not a bug in this tool and it cannot be fixed here.** A
bidirectional Bluetooth link is speech-bandwidth by nature; the same thing
happens on Windows during a Teams call. Mic input and hi-fi playback are
mutually exclusive on this hardware.

It is the reason the daemon signals call state *only* while an application
actually holds the microphone, rather than keeping the headset off-hook
permanently. You pay the cost during calls, when you were going to pay it
anyway, and never while you are just listening to music.

## Tested on

Developed against a **Jabra Evolve2 65** paired through a **Jabra Link 380**
(USB `0b0e:24c8`) on Arch Linux with PipeWire.

The HID Telephony report used here is part of the USB HID specification rather
than anything Jabra-specific, so other Jabra headsets and dongles that expose a
Telephony collection should work unchanged. Device matching is by vendor id
`0b0e` plus the presence of that collection, not by product. Reports of other
models working or failing are welcome.

## Configuration

Environment variables, if the defaults do not fit:

| Variable | Default | Purpose |
|---|---|---|
| `JABRA_DEVICE_MATCH` | `Jabra` | substring matched against PipeWire source names |
| `JABRA_CALL` | `jabra-call` | path to the `jabra-call` binary |
| `JABRA_DEBOUNCE` | `0.4` | seconds to settle before reacting to an audio event |

## Prior art

- [HeadsetControl](https://github.com/Sapd/HeadsetControl) — sidetone for gaming
  headsets. Supports Logitech, SteelSeries, Corsair, HyperX and others; **no
  Jabra support**.
- [jLink](https://github.com/Watchdog0x/jLink) — Jabra device management for
  Linux (discovery, pairing, battery). Does not implement sidetone or call
  state.

## License

MIT
