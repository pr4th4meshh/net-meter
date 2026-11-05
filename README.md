# NetMeter

A tiny, free, open-source **internet speed monitor for the macOS menu bar**.
It shows your live download ↓ and upload ↑ speed right next to the battery and Wi-Fi icons.

<img src="docs/screenshot.png" alt="NetMeter in the macOS menu bar showing upload and download speed" width="580">

- Live upload and download speed in B/s, KB/s, MB/s, GB/s (or Kbps / Mbps / Gbps)
- Three layouts: two stacked lines, a single line, or download only
- Update every 0.5, 1, 2 or 5 seconds
- Shows the data used since launch
- Can launch at login
- Adapts to light and dark mode
- No Dock icon, no tracking, no network requests. Under 500 lines of Swift.
- Works on Apple Silicon and Intel Macs, macOS 13 Ventura or later

## Install

### Option 1: one command (easiest)

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/pr4th4meshh/net-meter/main/install.sh | bash
```

This downloads the latest release, puts it in your Applications folder and opens it.
Run the same command again later to update. You can [read the script](install.sh) first.

### Option 2: download manually

1. Download **NetMeter.zip** from the [Releases](../../releases) page and unzip it.
2. Drag **NetMeter.app** into your **Applications** folder and open it.
3. macOS will say it can't verify the app. That's because it isn't notarized, which
   needs a paid Apple developer account; it doesn't mean anything is wrong. To allow it:
   - Click **Done** on the warning.
   - Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to NetMeter.
   - Confirm with your password or Touch ID. You only need to do this once.

   Or run this in Terminal instead: `xattr -dr com.apple.quarantine /Applications/NetMeter.app`

If you'd rather not trust a downloaded binary, build it yourself (below). It takes about 30 seconds.

## Moving the icon

Hold **⌘ Command** and **drag** the speed readout anywhere in the menu bar.
macOS remembers where you put it.

## Settings

Click the readout to open the menu, where you can choose:
**Units**, **Layout**, **Update Every**, **Launch at Login**, and **Quit**.

## Build from source

You only need Apple's free Command Line Tools (`xcode-select --install`). Xcode isn't required.

```bash
git clone https://github.com/pr4th4meshh/net-meter.git
cd net-meter
./build.sh
open build/NetMeter.app             # run it
cp -R build/NetMeter.app /Applications/   # install it
```

## How it works

Every tick, NetMeter reads the byte counters for each network interface through
`sysctl(NET_RT_IFLIST2)` and divides the change by the time elapsed. It only counts
physical interfaces (`en*` for Wi-Fi and Ethernet, `pdp_ip*`, `ppp*`). VPN tunnels,
AirDrop and loopback are left out, so the same traffic isn't counted twice.

| File | What it does |
|---|---|
| `Sources/NetMeter/NetworkMonitor.swift` | Reads the interface byte counters |
| `Sources/NetMeter/SpeedFormatter.swift` | Turns bytes/sec into text like `3.2 MB/s` |
| `Sources/NetMeter/AppDelegate.swift`    | Draws the menu bar item and the menu |

## Uninstall

Quit NetMeter from its menu, then delete `/Applications/NetMeter.app`.

## Releasing (for maintainers)

```bash
git tag v1.0.0 && git push origin v1.0.0
```
GitHub Actions builds the app and attaches `NetMeter.zip` to a new Release.

## License

MIT. Free to use, modify and share.
