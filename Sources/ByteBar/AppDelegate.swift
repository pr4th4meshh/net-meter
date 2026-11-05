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
        statusItem.autosaveName = "ByteBarStatusItem"
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        lastCounters = NetworkMonitor.readCounters()
        lastSampleTime = Date()

        refreshDisplay()
        startTimer()
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
        let down = "↓ " + SpeedFormatter.speed(downSpeed, unit: unit)
        let up = "↑ " + SpeedFormatter.speed(upSpeed, unit: unit)

        switch layout {
        case .stacked:  button.image = renderStacked(top: up, bottom: down)
        case .inline:   button.image = renderLine(down + "  " + up, widthTemplate: "↓ 888 MB/s  ↑ 888 MB/s")
        case .downOnly: button.image = renderLine(down, widthTemplate: "↓ 888 MB/s")
        }
        button.toolTip = "Download: \(down)\nUpload: \(up)"

        downItem.title = "Download:  " + SpeedFormatter.speed(downSpeed, unit: unit)
        upItem.title = "Upload:      " + SpeedFormatter.speed(upSpeed, unit: unit)
        totalItem.title = "Since launch:  ↓ \(SpeedFormatter.total(sessionTotal.received))  ↑ \(SpeedFormatter.total(sessionTotal.sent))"
    }

    /// Fixed width so the icon doesn't jitter as numbers change.
    private func width(of text: String, font: NSFont, template: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let templates = [template, template.replacingOccurrences(of: "MB/s", with: "Mbps")]
        let fixed = templates.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 0
        return ceil(max(fixed, (text as NSString).size(withAttributes: attrs).width))
    }

    private func renderStacked(top: String, bottom: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        let w = max(width(of: top, font: font, template: "↑ 888 MB/s"),
                    width(of: bottom, font: font, template: "↑ 888 MB/s"))
        let h: CGFloat = 22
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style,
                                                    .foregroundColor: NSColor.black]
        let image = NSImage(size: NSSize(width: w, height: h), flipped: true) { _ in
            (top as NSString).draw(in: NSRect(x: 0, y: 0, width: w, height: 11), withAttributes: attrs)
            (bottom as NSString).draw(in: NSRect(x: 0, y: 10.5, width: w, height: 11), withAttributes: attrs)
            return true
        }
        image.isTemplate = true // auto-adapts to light/dark menu bar
        return image
    }

    private func renderLine(_ text: String, widthTemplate: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let w = width(of: text, font: font, template: widthTemplate)
        let h: CGFloat = 22
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style,
                                                    .foregroundColor: NSColor.black]
        let textHeight = (text as NSString).size(withAttributes: attrs).height
        let image = NSImage(size: NSSize(width: w, height: h), flipped: true) { _ in
            (text as NSString).draw(in: NSRect(x: 0, y: (h - textHeight) / 2, width: w, height: textHeight),
                                    withAttributes: attrs)
            return true
        }
        image.isTemplate = true
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
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let tip = NSMenuItem(title: "Tip: hold ⌘ and drag to move this icon", action: nil, keyEquivalent: "")
        tip.isEnabled = false
        menu.addItem(tip)
        menu.addItem(ActionItem(title: "Quit ByteBar", key: "q") { NSApp.terminate(nil) })
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

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nTip: move ByteBar.app into your Applications folder first."
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
