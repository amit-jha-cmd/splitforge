import Foundation
import IOKit
import IOKit.hid
import SplitForgeCore

/// Concrete `HIDTransport` over IOKit/IOHIDManager. Matches the keyboard's Raw HID interface
/// by VID/PID + usage page `0xFF60`, opens it, forwards inbound reports to `onReport`, and
/// sends via `IOHIDDeviceSetReport`. This is the one place IOKit is used; everything above it
/// (`VialClient`, decoding, labeling) is pure and tested against a mock transport.
public final class IOKitHIDTransport: HIDTransport {
    public var onReport: (([UInt8]) -> Void)?
    /// Fired when a matching device is opened — the owner should start a keymap read here.
    public var onDeviceConnected: (() -> Void)?
    /// Fired when the matching device is removed.
    public var onDeviceDisconnected: (() -> Void)?

    public enum StartResult: Equatable { case ok, notPermitted, failed(IOReturn) }
    public enum TransportError: Error { case noDevice, sendFailed(IOReturn) }

    private let manager: IOHIDManager
    private let vid: Int?
    private let pid: Int?
    private let usagePage: Int
    private let usage: Int
    private var device: IOHIDDevice?
    // Input-report buffers must outlive their registration; one per device, freed on removal.
    private var buffers: [ObjectIdentifier: UnsafeMutablePointer<UInt8>] = [:]

    public init(vid: Int? = nil, pid: Int? = nil, usagePage: Int = 0xFF60, usage: Int = 0x61) {
        self.vid = vid
        self.pid = pid
        self.usagePage = usagePage
        self.usage = usage
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Schedules on the main run loop and opens the manager. The caller must run the run loop.
    @discardableResult
    public func start() -> StartResult {
        var matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage,
        ]
        if let vid { matching[kIOHIDVendorIDKey] = vid }
        if let pid { matching[kIOHIDProductIDKey] = pid }
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { c, _, _, dev in
            guard let c else { return }
            Unmanaged<IOKitHIDTransport>.fromOpaque(c).takeUnretainedValue().deviceAdded(dev)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { c, _, _, dev in
            guard let c else { return }
            Unmanaged<IOKitHIDTransport>.fromOpaque(c).takeUnretainedValue().deviceRemoved(dev)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        switch IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) {
        case kIOReturnSuccess: return .ok
        case kIOReturnNotPermitted: return .notPermitted
        case let other: return .failed(other)
        }
    }

    public func setReport(_ bytes: [UInt8]) throws {
        guard let device else { throw TransportError.noDevice }
        var report = bytes
        if report.count < Via.reportSize {
            report.append(contentsOf: repeatElement(0, count: Via.reportSize - report.count))
        }
        let result = report.withUnsafeBufferPointer { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return kIOReturnBadArgument }
            return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, base, report.count)
        }
        if result != kIOReturnSuccess { throw TransportError.sendFailed(result) }
    }

    private func deviceAdded(_ dev: IOHIDDevice) {
        device = dev
        let key = ObjectIdentifier(dev)
        freeBuffer(for: key)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Via.reportSize)
        buffer.initialize(repeating: 0, count: Via.reportSize)
        buffers[key] = buffer

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(dev, buffer, Via.reportSize, { c, _, _, _, _, report, length in
            guard let c else { return }
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            Unmanaged<IOKitHIDTransport>.fromOpaque(c).takeUnretainedValue().onReport?(bytes)
        }, ctx)

        onDeviceConnected?()
    }

    private func deviceRemoved(_ dev: IOHIDDevice) {
        let key = ObjectIdentifier(dev)
        freeBuffer(for: key)
        if let current = device, ObjectIdentifier(current) == key { device = nil }
        onDeviceDisconnected?()
    }

    private func freeBuffer(for key: ObjectIdentifier) {
        guard let buffer = buffers.removeValue(forKey: key) else { return }
        buffer.deinitialize(count: Via.reportSize)
        buffer.deallocate()
    }
}
