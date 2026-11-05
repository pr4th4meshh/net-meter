# ByteBar

A tiny, free, open-source **internet speed monitor for the macOS menu bar**.
It shows your live download ↓ and upload ↑ speed right next to the battery and Wi-Fi icons.

```
 ↑ 84 KB/s
 ↓ 3.2 MB/s     🔋 100%  📶  Fri 10:42
```

- Live upload and download speed in B/s, KB/s, MB/s, GB/s (or Kbps / Mbps / Gbps)
- Three layouts: two stacked lines, a single line, or download only
- Update every 0.5, 1, 2 or 5 seconds
- Shows the data used since launch
- Can launch at login
- Adapts to light and dark mode
- No Dock icon, no tracking, no network requests. Under 500 lines of Swift.
- Works on Apple Silicon and Intel Macs, macOS 13 Ventura or later

## Install

1. Download **ByteBar.zip** from the [Releases](../../releases) page and unzip it.
2. Drag **ByteBar.app** into your **Applications** folder.
3. The first time you open it, macOS will warn you because the app isn't notarized
   (notarizing requires a paid Apple developer account). To open it anyway:
   - **Right-click** ByteBar.app → **Open** → **Open**, or
   - go to **System Settings → Privacy & Security** and click **Open Anyway**, or
   - run this in Terminal: `xattr -dr com.apple.quarantine /Applications/ByteBar.app`

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
git clone https://github.com/<you>/ByteBar.git
cd ByteBar
./build.sh
open build/ByteBar.app             # run it
cp -R build/ByteBar.app /Applications/   # install it
```

## How it works

Every tick, ByteBar reads the byte counters for each network interface through
`sysctl(NET_RT_IFLIST2)` and divides the change by the time elapsed. It only counts
physical interfaces (`en*` for Wi-Fi and Ethernet, `pdp_ip*`, `ppp*`). VPN tunnels,
AirDrop and loopback are left out, so the same traffic isn't counted twice.

| File | What it does |
|---|---|
| `Sources/ByteBar/NetworkMonitor.swift` | Reads the interface byte counters |
| `Sources/ByteBar/SpeedFormatter.swift` | Turns bytes/sec into text like `3.2 MB/s` |
| `Sources/ByteBar/AppDelegate.swift`    | Draws the menu bar item and the menu |

## Uninstall

Quit ByteBar from its menu, then delete `/Applications/ByteBar.app`.

## Releasing (for maintainers)

```bash
git tag v1.0.0 && git push origin v1.0.0
```
GitHub Actions builds the app and attaches `ByteBar.zip` to a new Release.

## License

MIT. Free to use, modify and share.
