import AppKit

/// Checks GitHub for a newer release, but only when the user clicks
/// "Check for Updates…". NetMeter never contacts the network on its own.
final class UpdateChecker {
    static let repo = "pr4th4meshh/net-meter"
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    private static let installScript = "https://github.com/\(repo)/releases/latest/download/install.sh"

    private(set) var isChecking = false

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() {
        guard !isChecking else { return }
        isChecking = true

        var request = URLRequest(url: Self.latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let tag = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["tag_name"] as? String
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                if ok, let tag {
                    self.showResult(latest: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag)
                } else {
                    self.alert("Couldn't check for updates",
                               "GitHub couldn't be reached. Check your internet connection and try again."
                               + (error.map { "\n\n(\($0.localizedDescription))" } ?? ""))
                }
            }
        }.resume()
    }

    // MARK: Results

    private func showResult(latest: String) {
        guard Self.isVersion(latest, newerThan: currentVersion) else {
            alert("You're up to date", "NetMeter \(currentVersion) is the latest version.")
            return
        }

        if isHomebrewInstall {
            alert("NetMeter \(latest) is available",
                  "You have \(currentVersion). You installed NetMeter with Homebrew, so update it in Terminal:\n\nbrew upgrade netmeter")
            return
        }

        let a = NSAlert()
        a.messageText = "NetMeter \(latest) is available"
        a.informativeText = "You have \(currentVersion). Update now? NetMeter will close for a moment and reopen."
        a.addButton(withTitle: "Update Now")
        a.addButton(withTitle: "Release Notes")
        a.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        switch a.runModal() {
        case .alertFirstButtonReturn:  installUpdate()
        case .alertSecondButtonReturn: NSWorkspace.shared.open(Self.releasesPage)
        default: break
        }
    }

    /// Runs the same one-line installer people use to install NetMeter, pointed at
    /// the folder this copy lives in. It downloads the new version, quits this one,
    /// replaces it and opens the new one.
    private func installUpdate() {
        let appFolder = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        guard FileManager.default.isWritableFile(atPath: appFolder) else {
            NSWorkspace.shared.open(Self.releasesPage) // can't replace it ourselves; download manually
            return
        }

        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/NetMeter-update.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "curl -fsSL --connect-timeout 15 --max-time 60 \"$NETMETER_SCRIPT\" | bash"]
        var env = ProcessInfo.processInfo.environment
        env["NETMETER_SCRIPT"] = Self.installScript
        env["NETMETER_DIR"] = appFolder
        process.environment = env
        // Log to a file, not a pipe: the installer quits this app, and a pipe whose
        // reader has gone away would kill the installer mid-update.
        if let log = try? FileHandle(forWritingTo: logURL) {
            process.standardOutput = log
            process.standardError = log
        }
        process.terminationHandler = { [weak self] p in
            // On success the installer quits NetMeter before this runs, so we only get here on failure.
            guard p.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                self?.alert("Update failed",
                            "NetMeter couldn't download the update. Check your internet connection and try again.\n\nDetails: ~/Library/Logs/NetMeter-update.log")
            }
        }
        do {
            try process.run()
        } catch {
            alert("Update failed", error.localizedDescription)
        }
    }

    // MARK: Helpers

    private var isHomebrewInstall: Bool {
        ["/opt/homebrew/Caskroom/netmeter", "/usr/local/Caskroom/netmeter"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Compares dotted versions numerically, so 1.0.10 is newer than 1.0.9.
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true) // menu bar apps must come forward to show alerts
        a.runModal()
    }
}
