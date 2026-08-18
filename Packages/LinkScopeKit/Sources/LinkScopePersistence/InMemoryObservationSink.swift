import Foundation
import LinkScopeCore

public actor InMemoryObservationSink: ObservationSink {
    public private(set) var observations: [ResolvedObservation] = []
    public private(set) var statuses: [ProviderStatus] = []
    public private(set) var events: [TimelineEvent] = []

    public init() {}

    public func persist(_ observation: ResolvedObservation) {
        observations.append(observation)
    }

    public func persist(_ status: ProviderStatus) {
        statuses.append(status)
    }

    public func persist(_ event: TimelineEvent) {
        events.append(event)
    }
}

