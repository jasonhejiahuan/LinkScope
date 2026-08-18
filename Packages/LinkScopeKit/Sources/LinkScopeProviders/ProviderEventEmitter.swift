import Foundation
import LinkScopeCore

final class ProviderEventEmitter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<ProviderEvent>.Continuation?
    private var buffered: [ProviderEvent] = []

    func stream() -> AsyncStream<ProviderEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(2_000)) { continuation in
            lock.withLock {
                self.continuation = continuation
                for event in buffered {
                    continuation.yield(event)
                }
                buffered.removeAll()
            }
        }
    }

    func yield(_ event: ProviderEvent) {
        lock.withLock {
            if let continuation {
                continuation.yield(event)
            } else {
                buffered.append(event)
            }
        }
    }

    func finish() {
        lock.withLock {
            continuation?.finish()
            continuation = nil
            buffered.removeAll()
        }
    }
}

public enum PublicProviderIDs {
    public static let coreHID: ProviderID = "public.corehid"
    public static let ioBluetooth: ProviderID = "public.iobluetooth"
    public static let coreBluetooth: ProviderID = "public.corebluetooth"
    public static let coreAudio: ProviderID = "public.coreaudio"
    public static let gameController: ProviderID = "public.gamecontroller"
    public static let ioRegistry: ProviderID = "public.ioregistry"
    public static let systemEvents: ProviderID = "public.system-events"
}

enum ProviderObservationFactory {
    static func available(
        transport: TransportIdentity,
        path: String,
        value: RawValue,
        sensitivity: DataSensitivity = .ordinary
    ) -> ProviderEvent {
        .observation(.available(
            transport: transport,
            path: ParameterPath(rawValue: path),
            value: value,
            sensitivity: sensitivity
        ))
    }

    static func unavailable(
        transport: TransportIdentity,
        path: String,
        availability: ParameterAvailability,
        sensitivity: DataSensitivity = .ordinary
    ) -> ProviderEvent {
        .observation(AccessoryObservation(
            transportIdentity: transport,
            parameterPath: ParameterPath(rawValue: path),
            value: nil,
            availability: availability,
            sensitivity: sensitivity
        ))
    }
}

