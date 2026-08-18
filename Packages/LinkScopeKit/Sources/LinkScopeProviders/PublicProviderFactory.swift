import Foundation
import LinkScopeCore

public enum PublicProviderFactory {
    public static func makeProviders() -> [any AccessoryProvider] {
        [
            CoreHIDProvider(),
            IOBluetoothProvider(),
            CoreBluetoothProvider(),
            CoreAudioProvider(),
            GameControllerProvider(),
            IORegistryProvider(),
            SystemEventProvider()
        ]
    }

    public static func descriptors() -> [ProviderDescriptor] {
        makeProviders().map(\.descriptor)
    }
}

