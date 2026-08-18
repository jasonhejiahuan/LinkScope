import Foundation
import Testing
@testable import LinkScopeCore

@Test func displayNameAloneNeverMergesAccessories() async {
    let resolver = IdentityResolver()
    let first = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "hid-one",
        displayName: "Magic Trackpad"
    )
    let second = TransportIdentity(
        providerID: "bluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "bt-two",
        displayName: "Magic Trackpad"
    )

    let firstResolution = await resolver.resolve(first)
    let secondResolution = await resolver.resolve(second)

    #expect(firstResolution.physicalAccessory.id != secondResolution.physicalAccessory.id)
    #expect(secondResolution.resolution == .ambiguous)
}

@Test func exactTransportIdentityIsStable() async {
    let resolver = IdentityResolver()
    let first = TransportIdentity(
        providerID: "corebluetooth",
        kind: .coreBluetooth,
        rawIdentifier: "7C1C12A8-8A22-4634-9F14-A0854237E579",
        displayName: "Sensor"
    )
    let repeated = TransportIdentity(
        providerID: "corebluetooth",
        kind: .coreBluetooth,
        rawIdentifier: "7C1C12A8-8A22-4634-9F14-A0854237E579",
        displayName: "Renamed Sensor"
    )

    let initial = await resolver.resolve(first)
    let resolved = await resolver.resolve(repeated)

    #expect(initial.physicalAccessory.id == resolved.physicalAccessory.id)
    #expect(initial.transportIdentity.id == resolved.transportIdentity.id)
    #expect(resolved.resolution == .exact)
}

@Test func coreBluetoothIdentifierHasNoMacSemantics() {
    let identity = TransportIdentity(
        providerID: "corebluetooth",
        kind: .coreBluetooth,
        rawIdentifier: "7C1C12A8-8A22-4634-9F14-A0854237E579"
    )

    #expect(identity.kind == .coreBluetooth)
    #expect(identity.rawIdentifier.contains("-"))
    #expect(!identity.rawIdentifier.contains(":"))
}

@Test func providerPhysicalGroupMergesSiblingEndpoints() async {
    let resolver = IdentityResolver()
    let first = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:1",
        displayName: "Apple Internal Keyboard / Trackpad",
        physicalGroupIdentifier: "built-in:FIFO:49"
    )
    let second = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:2",
        displayName: "Apple Internal Keyboard / Trackpad",
        physicalGroupIdentifier: "built-in:FIFO:49"
    )

    let firstResolution = await resolver.resolve(first)
    let secondResolution = await resolver.resolve(second)

    #expect(firstResolution.physicalAccessory.id == secondResolution.physicalAccessory.id)
    #expect(firstResolution.transportIdentity.id != secondResolution.transportIdentity.id)
    #expect(secondResolution.resolution == .correlated(confidence: 0.99))
}

@Test func verifiedAncestryCanReconcilePreviouslySplitExactTransports() async {
    let resolver = IdentityResolver()
    let firstPhysical = PhysicalAccessoryIdentity(displayName: "Internal Keyboard")
    let secondPhysical = PhysicalAccessoryIdentity(displayName: "Internal Keyboard")
    let firstLegacy = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:1",
        displayName: "Internal Keyboard"
    )
    let secondLegacy = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:2",
        displayName: "Internal Keyboard"
    )
    _ = await resolver.resolve(firstLegacy, preferredPhysical: firstPhysical)
    _ = await resolver.resolve(secondLegacy, preferredPhysical: secondPhysical)

    let firstCurrent = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:1",
        displayName: "Internal Keyboard",
        registryAncestryID: "ioregistry:shared-parent"
    )
    let secondCurrent = TransportIdentity(
        providerID: "hid",
        kind: .coreHID,
        rawIdentifier: "registry:2",
        displayName: "Internal Keyboard",
        registryAncestryID: "ioregistry:shared-parent"
    )
    let firstResolution = await resolver.resolve(firstCurrent)
    let secondResolution = await resolver.resolve(secondCurrent)

    #expect(firstResolution.physicalAccessory.id == secondResolution.physicalAccessory.id)
    #expect(secondResolution.resolution == .verifiedAncestry)
}

@Test func bluetoothDomainCorrelatesUniqueCrossProviderEndpoints() async {
    let resolver = IdentityResolver()
    let bluetooth = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "address:one",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        connectionProtocol: .bluetooth
    )
    let audio = TransportIdentity(
        providerID: "coreaudio",
        kind: .coreAudio,
        rawIdentifier: "audio:one",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        connectionProtocol: .bluetooth
    )

    let bluetoothResolution = await resolver.resolve(bluetooth)
    let audioResolution = await resolver.resolve(audio)

    #expect(bluetoothResolution.physicalAccessory.id == audioResolution.physicalAccessory.id)
    #expect(audioResolution.resolution == .correlated(confidence: 0.75))
}

@Test func softCorrelationNeverCollapsesSameKindNameDuplicates() async {
    let resolver = IdentityResolver()
    let first = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "address:one",
        displayName: "AirPods",
        correlationDomain: "bluetooth-accessory"
    )
    let second = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "address:two",
        displayName: "AirPods",
        correlationDomain: "bluetooth-accessory"
    )

    let firstResolution = await resolver.resolve(first)
    let secondResolution = await resolver.resolve(second)

    #expect(firstResolution.physicalAccessory.id != secondResolution.physicalAccessory.id)
    #expect(secondResolution.resolution == .ambiguous)
}

@Test func crossProviderIdentifierAnchorsRotatingBluetoothAlias() async {
    let resolver = IdentityResolver()
    let rotatingAlias = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "C0:38:B9:4C:A0:20",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:c038b94ca020",
        connectionProtocol: .bluetooth
    )
    let savedIdentity = TransportIdentity(
        providerID: "iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "54:2A:43:3C:AB:99",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:542a433cab99",
        connectionProtocol: .bluetooth
    )
    let audioEndpoint = TransportIdentity(
        providerID: "coreaudio",
        kind: .coreAudio,
        rawIdentifier: "54-2A-43-3C-AB-99::input",
        displayName: "J-4ANC",
        correlationDomain: "bluetooth-accessory",
        crossProviderIdentifier: "bluetooth-address:542a433cab99",
        connectionProtocol: .bluetooth
    )

    let rotatingResolution = await resolver.resolve(rotatingAlias)
    _ = await resolver.resolve(savedIdentity)
    let audioResolution = await resolver.resolve(audioEndpoint)
    let rotatingAgain = await resolver.resolve(rotatingAlias)

    #expect(audioResolution.resolution == .correlated(confidence: 0.98))
    #expect(rotatingResolution.physicalAccessory.id != audioResolution.physicalAccessory.id)
    #expect(rotatingAgain.physicalAccessory.id == audioResolution.physicalAccessory.id)
}

@Test func developmentFixturesAreExplicitlyRecognized() {
    let legacy = TransportIdentity(
        providerID: "public.provider",
        kind: .mock,
        rawIdentifier: "legacy"
    )
    let reservedProvider = TransportIdentity(
        providerID: "fixture.bluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "fixture"
    )
    let production = TransportIdentity(
        providerID: "public.iobluetooth",
        kind: .ioBluetooth,
        rawIdentifier: "system-record"
    )

    #expect(DevelopmentFixturePolicy.isDevelopmentFixture(legacy))
    #expect(DevelopmentFixturePolicy.isDevelopmentFixture(reservedProvider))
    #expect(!DevelopmentFixturePolicy.isDevelopmentFixture(production))
}
