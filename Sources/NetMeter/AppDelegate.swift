import AppKit
import ServiceManagement

enum Layout: String, CaseIterable {
    case stacked   // upload on top, download below (two small lines)
    case inline    // "↓ 1.2 MB/s  ↑ 80 KB/s" on one line
    case downOnly  // just download

    var title: String {
        switch self {
        case .stacked:  return "Stacked (two lines)"
        case .inline:   return "Single line"
        case .downOnly: return "Download only"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private var lastCounters: InterfaceCounters?
    private var lastSampleTime = Date()
    private var sessionTotal = NetCounters(received: 0, sent: 0)
    private var downSpeed: Double = 0
    private var upSpeed: Double = 0

    // Menu items updated live while the menu is open
    private let downItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let upItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let totalItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    // MARK: Settings (persisted in UserDefaults)

    private let defaults = UserDefaults.standard

    private var unit: SpeedUnit {
        get { SpeedUnit(rawValue: defaults.string(forKey: "unit") ?? "") ?? .bytes }
        set { defaults.set(newValue.rawValue, forKey: "unit"); refreshDisplay() }
    }

    private var layout: Layout {
        get { Layout(rawValue: defaults.string(forKey: "layout") ?? "") ?? .stacked }
        set { defaults.set(newValue.rawValue, forKey: "layout"); refreshDisplay() }
    }

    private var interval: TimeInterval {
        get { let v = defaults.double(forKey: "interval"); return v > 0 ? v : 1 }
        set { defaults.set(newValue, forKey: "interval"); startTimer() }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Remembers where the user ⌘-dragged the icon in the menu bar.
        statusItem.autosaveName = "NetMeterStatusItem"
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        lastCounters = NetworkMonitor.readCounters()
        lastSampleTime = Date()

        refreshDisplay()
        startTimer()
        enableLaunchAtLoginOnFirstRun()
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(t, forMode: .common) // keep ticking while the menu is open
        timer = t
    }

    private func sample() {
        guard let now = NetworkMonitor.readCounters() else { return }
        let time = Date()
        let elapsed = time.timeIntervalSince(lastSampleTime)

        if let last = lastCounters, elapsed > 0 {
            let d = now.delta(since: last)
            downSpeed = Double(d.received) / elapsed
            upSpeed = Double(d.sent) / elapsed
            sessionTotal.received &+= d.received
            sessionTotal.sent &+= d.sent
        }
        lastCounters = now
        lastSampleTime = time
        refreshDisplay()
    }

    // MARK: Menu bar rendering

    private func refreshDisplay() {
        guard let button = statusItem?.button else { return }
        // Arrows go at the END so they stay pinned to the right edge of each
        // fixed-width column; only the numbers move as the speed changes.
        let down = SpeedFormatter.speed(downSpeed, unit: unit) + " ↓"
        let up = SpeedFormatter.speed(upSpeed, unit: unit) + " ↑"

        switch layout {
        case .stacked:  button.image = render(rows: [[up], [down]], fontSize: 9.5, weight: .medium)
        case .inline:   button.image = render(rows: [[down, up]], fontSize: 12, weight: .regular)
        case .downOnly: button.image = render(rows: [[down]], fontSize: 12, weight: .regular)
        }
        button.toolTip = "Download: \(SpeedFormatter.speed(downSpeed, unit: unit))\nUpload: \(SpeedFormatter.speed(upSpeed, unit: unit))"

        downItem.title = "Download:  " + SpeedFormatter.speed(downSpeed, unit: unit)
        upItem.title = "Upload:      " + SpeedFormatter.speed(upSpeed, unit: unit)
        totalItem.title = "Since launch:  ↓ \(SpeedFormatter.total(sessionTotal.received))  ↑ \(SpeedFormatter.total(sessionTotal.sent))"
    }

    /// Draws text as a grid of fixed-width, right-aligned columns.
    /// The column width comes from the widest possible value, so the image
    /// size and the arrow positions never change as the numbers do.
    private func render(rows: [[String]], fontSize: CGFloat, weight: NSFont.Weight) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style,
                                                    .foregroundColor: NSColor.black]
        func textWidth(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: attrs).width }

        let widest = ["888 MB/s ↓", "888 Mbps ↓", "888 Kbps ↓"] + rows.flatMap { $0 }
        let columnWidth = ceil(widest.map(textWidth).max() ?? 0)
        let gap: CGFloat = 8
        let columns = CGFloat(rows.map(\.count).max() ?? 1)
        let w = columnWidth * columns + gap * (columns - 1)
        let h: CGFloat = 22
        let lineHeight = ceil(font.ascender - font.descender)
        let rowStep = rows.count > 1 ? min(lineHeight, h / CGFloat(rows.count)) : lineHeight
        let top = (h - rowStep * CGFloat(rows.count - 1) - lineHeight) / 2

        let image = NSImage(size: NSSize(width: w, height: h), flipped: true) { _ in
            for (r, row) in rows.enumerated() {
                for (c, text) in row.enumerated() {
                    let x = CGFloat(c) * (columnWidth + gap)
                    let y = top + CGFloat(r) * rowStep
                    (text as NSString).draw(in: NSRect(x: x, y: y, width: columnWidth, height: lineHeight),
                                            withAttributes: attrs)
                }
            }
            return true
        }
        image.isTemplate = true // auto-adapts to light/dark menu bar
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        refreshDisplay()

        for item in [downItem, upItem, totalItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(submenu("Units", SpeedUnit.allCases.map { u in
            (u.title, u == unit, { [weak self] in self?.unit = u })
        }))
        menu.addItem(submenu("Layout", Layout.allCases.map { l in
            (l.title, l == layout, { [weak self] in self?.layout = l })
        }))
        menu.addItem(submenu("Update Every", [0.5, 1, 2, 5].map { s in
            (s == 0.5 ? "0.5 seconds" : "\(Int(s)) second\(s == 1 ? "" : "s")", s == interval,
             { [weak self] in self?.interval = s })
        }))

        let login = ActionItem(title: "Launch at Login") { [weak self] in self?.toggleLaunchAtLogin() }
        login.state = launchAtLoginIsOn ? .on : .off
        if SMAppService.mainApp.status == .requiresApproval {
            login.title = "Launch at Login (approve in System Settings)"
        }
        menu.addItem(login)

        menu.addItem(.separator())
        let tip = NSMenuItem(title: "Tip: hold ⌘ and drag to move this icon", action: nil, keyEquivalent: "")
        tip.isEnabled = false
        menu.addItem(tip)
        menu.addItem(ActionItem(title: "Quit NetMeter", key: "q") { NSApp.terminate(nil) })
    }

    private func submenu(_ title: String, _ options: [(String, Bool, () -> Void)]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (name, selected, action) in options {
            let item = ActionItem(title: name, handler: action)
            item.state = selected ? .on : .off
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    /// True for installed copies (in /Applications or ~/Applications), so a
    /// development build run from the project folder never registers itself.
    private var isInstalled: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private var launchAtLoginIsOn: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    /// On the first run of an installed copy, start NetMeter at every login
    /// automatically. After that the user's choice in the menu is respected.
    private func enableLaunchAtLoginOnFirstRun() {
        guard isInstalled, !defaults.bool(forKey: "launchAtLoginConfigured") else { return }
        if !launchAtLoginIsOn { try? SMAppService.mainApp.register() }
        if launchAtLoginIsOn { defaults.set(true, forKey: "launchAtLoginConfigured") } // else retry next launch
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLoginIsOn {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems() // let the user approve it
                }
            }
            defaults.set(true, forKey: "launchAtLoginConfigured")
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nTip: move NetMeter.app into your Applications folder first."
            alert.runModal()
        }
    }
}

/// NSMenuItem that runs a closure when clicked.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
