import Foundation
import IOKit
import IOKit.hid
import SplitForgeCore

/// Result of starting a source, transport-agnostic. IOKit's `IOReturn` detail is mapped to a
/// string so the app can switch on this without importing IOKit.
public enum TransportStart: Equatable {
    case ok
    case notPermitted
    case failed(String)
}

/// A `HIDTransport` the app can manage uniformly: connection-lifecycle callbacks plus a single
/// `startSource()`. Lets `AppDelegate` hold either the IOKit (USB) or the Pi-bridge (network)
/// transport behind one type and wire them identically.
public protocol HIDSource: HIDTransport {
    var onDeviceConnected: (() -> Void)? { get set }
    var onDeviceDisconnected: (() -> Void)? { get set }
    func startSource() -> TransportStart
}

// IOKitHIDTransport already exposes onReport/setReport/onDeviceConnected/onDeviceDisconnected, so it
// conforms with just the start() adapter below — no change to IOKitHIDTransport.swift itself.
extension IOKitHIDTransport: HIDSource {
    public func startSource() -> TransportStart {
        switch start() {
        case .ok: return .ok
        case .notPermitted: return .notPermitted
        case .failed(let r): return .failed(String(format: "0x%08X", UInt32(bitPattern: r)))
        }
    }

    /// True if a matching Raw HID device is currently attached to *this* Mac. Synchronous and does
    /// not open the device (so it never triggers an Input Monitoring prompt) — used for `.auto`
    /// selection: USB wins when the Totem is plugged in here, otherwise fall back to the Pi bridge.
    public static func matchingDevicePresent(vid: Int?, pid: Int?,
                                             usagePage: Int = 0xFF60, usage: Int = 0x61) -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        var matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage,
        ]
        if let vid { matching[kIOHIDVendorIDKey] = vid }
        if let pid { matching[kIOHIDProductIDKey] = pid }
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        // Open so enumeration is populated; closing right after. Enumeration doesn't need Input
        // Monitoring (that gates *reading reports*), so this never prompts for a mere presence check.
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        guard let devices = IOHIDManagerCopyDevices(manager) else { return false }
        return CFSetGetCount(devices) > 0
    }
}
