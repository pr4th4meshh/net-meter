import Darwin
import Foundation

/// Bytes received / sent on one network interface.
struct NetCounters {
    var received: UInt64
    var sent: UInt64
}

/// Counters for every counted interface, keyed by interface name (e.g. "en0").
typealias InterfaceCounters = [String: NetCounters]

extension InterfaceCounters {
    /// Bytes transferred between two snapshots, summed over interfaces.
    /// Interfaces that appeared/disappeared are ignored, and counters that
    /// wrapped around (some macOS versions report them as 32-bit) are handled.
    func delta(since old: InterfaceCounters) -> NetCounters {
        var result = NetCounters(received: 0, sent: 0)
        for (name, now) in self {
            guard let before = old[name] else { continue }
            result.received &+= Self.diff(now.received, before.received)
            result.sent &+= Self.diff(now.sent, before.sent)
        }
        return result
    }

    private static func diff(_ now: UInt64, _ before: UInt64) -> UInt64 {
        if now >= before { return now - before }
        if before <= UInt64(UInt32.max) { return (now &+ (1 << 32)) &- before } // 32-bit wrap
        return 0 // counter reset
    }
}

enum NetworkMonitor {
    /// Interfaces that carry real internet traffic. Virtual interfaces such as
    /// `utun` (VPNs), `awdl` (AirDrop), `bridge` and loopback are skipped so the
    /// same bytes aren't counted twice.
    private static let countedPrefixes = ["en", "pdp_ip", "ppp"]

    /// Reads per-interface byte counters via sysctl(NET_RT_IFLIST2).
    /// Values may still be truncated to 32 bits by the OS; `delta(since:)` handles that.
    static func readCounters() -> InterfaceCounters? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, u_int(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var result: InterfaceCounters = [:]
        var nameBuffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))

        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let isUp = msg.ifm_flags & IFF_UP != 0
                    let isLoopback = msg.ifm_flags & IFF_LOOPBACK != 0

                    if isUp, !isLoopback,
                       if_indextoname(UInt32(msg.ifm_index), &nameBuffer) != nil {
                        let name = String(cString: nameBuffer)
                        if countedPrefixes.contains(where: { name.hasPrefix($0) }) {
                            result[name] = NetCounters(received: msg.ifm_data.ifi_ibytes,
                                                       sent: msg.ifm_data.ifi_obytes)
                        }
                    }
                }
                offset += messageLength
            }
        }
        return result
    }
}
