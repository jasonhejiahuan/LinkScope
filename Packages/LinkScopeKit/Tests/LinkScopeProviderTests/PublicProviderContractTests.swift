import LinkScopeCore
import LinkScopeProviders
import Testing

@Test func everyPublicProviderHasStableReadOnlyCapabilities() {
    let providers = PublicProviderFactory.makeProviders()
    #expect(providers.count == 7)
    #expect(Set(providers.map { $0.descriptor.id }).count == providers.count)

    for provider in providers {
        #expect(!provider.descriptor.capabilities.isEmpty)
        #expect(provider.descriptor.capabilities.allSatisfy {
            [.read, .observe, .sample, .diagnose].contains($0.operation)
        })
        #expect(!provider.descriptor.isExperimental)
    }
}

@Test func coreBluetoothDescriptorDoesNotClaimArbitraryEnumeration() {
    let descriptor = PublicProviderFactory.descriptors().first {
        $0.id == PublicProviderIDs.coreBluetooth
    }
    #expect(descriptor != nil)
    #expect(descriptor?.capabilities.contains { $0.id.contains("arbitrary") } == false)
}

