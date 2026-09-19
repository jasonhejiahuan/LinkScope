import Foundation
import Testing
@testable import LinkScopeCore

private let diagnosticTransport = TransportIdentity(
    providerID: "unit.monitor",
    kind: .system,
    rawIdentifier: "diagnostic-fixture"
)

private func diagnosticObservation(
    value: RawValue?,
    availability: ParameterAvailability = .available
) -> AccessoryObservation {
    AccessoryObservation(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        transportIdentity: diagnosticTransport,
        parameterPath: "battery.level",
        value: value,
        availability: availability
    )
}

@Test func monitoringRuleEvaluatorMatchesObservationPredicates() {
    let previous = diagnosticObservation(value: .double(0.8))
    let current = diagnosticObservation(value: .double(0.4))

    #expect(MonitoringRuleEvaluator.matches(
        .numericBelow(0.5),
        observation: current,
        previous: previous
    ))
    #expect(!MonitoringRuleEvaluator.matches(
        .numericAbove(0.5),
        observation: current,
        previous: previous
    ))
    #expect(MonitoringRuleEvaluator.matches(
        .changed,
        observation: current,
        previous: previous
    ))
    #expect(!MonitoringRuleEvaluator.matches(
        .changed,
        observation: current,
        previous: nil
    ))

    let unavailable = diagnosticObservation(
        value: nil,
        availability: .notReported(detail: "fixture")
    )
    #expect(MonitoringRuleEvaluator.matches(
        .availability(.notReported),
        observation: unavailable,
        previous: current
    ))
}

@Test func providerHealthRulesHaveExplicitNonNumericSemantics() {
    #expect(MonitoringRuleEvaluator.matchesProviderStatus(
        .availability(.providerFailure),
        state: .failed,
        previous: .running
    ))
    #expect(MonitoringRuleEvaluator.matchesProviderStatus(
        .changed,
        state: .permissionDenied,
        previous: .running
    ))
    #expect(!MonitoringRuleEvaluator.matchesProviderStatus(
        .numericBelow(1),
        state: .failed,
        previous: .running
    ))
    #expect(!MonitoringRuleEvaluator.matchesProviderStatus(
        .changed,
        state: .failed,
        previous: nil
    ))
}

@Test func eventOnlyDiagnosticsNeverReceiveAPeriodicInterval() {
    #expect(DiagnosticSamplingScheduler.periodicInterval(for: .eventOnly) == nil)
    #expect(DiagnosticSamplingScheduler.periodicInterval(
        for: .fixedInterval(seconds: 0.25)
    ) == 2)
    #expect(DiagnosticSamplingScheduler.periodicInterval(
        for: .adaptive(minimumSeconds: 5, maximumSeconds: 30)
    ) == 5)
}

@Test func monitoringCatalogIncludesEventOnlyBatterySources() throws {
    let physical = PhysicalAccessoryIdentity(displayName: "Fixture Accessory")
    let identity = ResolvedIdentity(
        physicalAccessory: physical,
        transportIdentity: diagnosticTransport,
        resolution: .independent
    )
    let battery = ResolvedObservation(
        observation: diagnosticObservation(value: .double(0.75)),
        identity: identity
    )
    let rssi = ResolvedObservation(
        observation: AccessoryObservation(
            transportIdentity: diagnosticTransport,
            parameterPath: "radio.rssi",
            value: .signedInt(-55),
            availability: .available
        ),
        identity: identity
    )
    let provider = ProviderDescriptor(
        id: diagnosticTransport.providerID,
        displayName: "Fixture Provider",
        transportKind: .system,
        capabilities: [
            ProviderCapability(
                id: "battery.observe",
                operation: .observe,
                parameterPath: "battery.level"
            ),
            ProviderCapability(
                id: "rssi.sample",
                operation: .sample,
                parameterPath: "radio.rssi"
            )
        ]
    )

    let monitoring = DiagnosticSourceCatalog.monitoringSources(
        observations: [battery, rssi],
        providers: [provider]
    )
    let sampled = DiagnosticSourceCatalog.sampleSources(
        observations: [battery, rssi],
        providers: [provider]
    )

    #expect(Set(monitoring.map(\.parameterPath)) == Set<ParameterPath>([
        "battery.level",
        "radio.rssi"
    ]))
    #expect(sampled.map(\.parameterPath) == ["radio.rssi"])
    let batterySource = try #require(monitoring.first {
        $0.parameterPath == "battery.level"
    })
    #expect(batterySource.operation == .observe)
}

@Test func ruleRepeatIntervalUsesThePersistedTriggerDate() {
    let lastTrigger = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(!MonitoringRuleEvaluator.canTrigger(
        minimumRepeatInterval: 300,
        lastTriggeredAt: lastTrigger,
        now: lastTrigger.addingTimeInterval(299)
    ))
    #expect(MonitoringRuleEvaluator.canTrigger(
        minimumRepeatInterval: 300,
        lastTriggeredAt: lastTrigger,
        now: lastTrigger.addingTimeInterval(300)
    ))
}
