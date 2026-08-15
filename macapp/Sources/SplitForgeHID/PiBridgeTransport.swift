import Foundation
import Network
import SplitForgeCore

/// A `HIDSource` that reaches the Totem's `0xFF60` Vial interface over TCP via the Pi's
/// `rawhid_server`, instead of local IOKit — used when the Totem is routed through the Pi.
///
/// Wire format matches `IOKitHIDTransport`: 32-byte reports both ways, so `VialClient`,
/// `LayerReport`, and `KeyPressReport` work unchanged. Callbacks are delivered on the main
/// thread (like IOKit's run-loop callbacks) so the app can mutate its store/AppKit directly.
/// Needs no Input Monitoring permission — it's a network socket, not local HID.
///
/// All mutable state is confined to `queue` (a serial queue); only the consumer callbacks hop to
/// the main thread. Auto-reconnects with a short backoff so the visualizer recovers if the Pi or
/// the link blips.
public final class PiBridgeTransport: HIDSource {
    public var onReport: (([UInt8]) -> Void)?
    public var onDeviceConnected: (() -> Void)?
    public var onDeviceDisconnected: (() -> Void)?

    private let endpointHost: NWEndpoint.Host
    private let endpointPort: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.splitforge.pibridge")
    private var connection: NWConnection?
    private var assembler = FrameAssembler(frameSize: Via.reportSize)
    private var running = false
    private var linkUp = false
    private var reconnectScheduled = false
    // Pace outbound reports. VialClient fires ~47 requests in one burst; over local USB the
    // synchronous IOKit setReport paced them, but the network path must re-introduce a gap so the
    // Totem's raw-HID endpoint doesn't drop most of them (which stalls the keymap read).
    private var nextSend: DispatchTime = .now()
    private let sendGap: DispatchTimeInterval = .milliseconds(8)

    public init(host: String, port: Int) {
        endpointHost = NWEndpoint.Host(host)
        endpointPort = NWEndpoint.Port(rawValue: UInt16(truncatingIfNeeded: port))
            ?? NWEndpoint.Port(rawValue: UInt16(Settings.defaultPiBridgePort))!
    }

    public func startSource() -> TransportStart {
        queue.async { [weak self] in
            guard let self else { return }
            self.running = true
            self.connect()
        }
        return .ok  // connects asynchronously; onDeviceConnected fires when the link is up
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.running = false
            self.connection?.cancel()
            self.connection = nil
        }
    }

    // MARK: - queue-confined internals

    private func connect() {
        guard running else { return }
        connection?.cancel()
        assembler.reset()
        nextSend = .now()
        let conn = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.linkUp = true
                self.emit { $0.onDeviceConnected }
                self.receive(on: conn)
            case .failed, .cancelled:
                self.dropLink()
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                for frame in self.assembler.push([UInt8](data)) {
                    let payload = frame
                    DispatchQueue.main.async { self.onReport?(payload) }
                }
            }
            if error != nil || isComplete {
                self.dropLink()
                return
            }
            self.receive(on: conn)
        }
    }

    private func dropLink() {
        if linkUp {
            linkUp = false
            emit { $0.onDeviceDisconnected }
        }
        guard running, !reconnectScheduled else { return }
        reconnectScheduled = true
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.reconnectScheduled = false
            self.connect()
        }
    }

    public func setReport(_ bytes: [UInt8]) throws {
        let report = Via.padded(bytes)
        queue.async { [weak self] in
            guard let self else { return }
            let now = DispatchTime.now()
            let sendAt = max(now, self.nextSend)
            self.nextSend = sendAt + self.sendGap
            self.queue.asyncAfter(deadline: sendAt) { [weak self] in
                self?.connection?.send(content: Data(report), completion: .idempotent)
            }
        }
    }

    /// Delivers one of the lifecycle callbacks on the main thread.
    private func emit(_ pick: (PiBridgeTransport) -> (() -> Void)?) {
        let cb = pick(self)
        DispatchQueue.main.async { cb?() }
    }
}
