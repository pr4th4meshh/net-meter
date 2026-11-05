import Foundation

enum SpeedUnit: String, CaseIterable {
    case bytes   // KB/s, MB/s, GB/s
    case bits    // Kbps, Mbps, Gbps

    var title: String {
        switch self {
        case .bytes: return "Bytes (KB/s, MB/s, GB/s)"
        case .bits:  return "Bits (Kbps, Mbps, Gbps)"
        }
    }
}

enum SpeedFormatter {
    /// Formats a speed given in bytes per second, e.g. "512 B/s", "1.4 MB/s", "87 Mbps".
    static func speed(_ bytesPerSecond: Double, unit: SpeedUnit) -> String {
        switch unit {
        case .bytes:
            return scaled(bytesPerSecond, base: 1024,
                          labels: ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"])
        case .bits:
            return scaled(bytesPerSecond * 8, base: 1000,
                          labels: ["bps", "Kbps", "Mbps", "Gbps", "Tbps"])
        }
    }

    /// Formats a byte total, e.g. "3.2 GB".
    static func total(_ bytes: UInt64) -> String {
        scaled(Double(bytes), base: 1024, labels: ["B", "KB", "MB", "GB", "TB", "PB"])
    }

    private static func scaled(_ value: Double, base: Double, labels: [String]) -> String {
        var v = max(0, value)
        var index = 0
        // Switch to the next unit once we'd need 4 digits, keeping the text short.
        while v >= 1000 && index < labels.count - 1 {
            v /= base
            index += 1
        }
        if index == 0 || v >= 10 {
            return "\(Int(v.rounded())) \(labels[index])"
        }
        return String(format: "%.1f %@", v, labels[index])
    }
}
