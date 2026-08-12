/// The minimal device I/O the VIA reader needs, kept as a protocol so the IOKit
/// implementation lives in a separate target and `VialClient` stays pure and testable.
///
/// The owner (app or spike) is responsible for wiring `onReport` — typically routing
/// layer broadcasts to `LayerReport.decode` and everything else to `VialClient.handle`.
public protocol HIDTransport: AnyObject {
    /// Send a report to the device (host → device). Implementations pad to the report size.
    func setReport(_ bytes: [UInt8]) throws

    /// Called for every inbound report (device → host). Set by the consumer.
    var onReport: (([UInt8]) -> Void)? { get set }
}
