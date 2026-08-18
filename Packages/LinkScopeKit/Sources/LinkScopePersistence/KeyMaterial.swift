import CryptoKit
import Foundation
import Security

public enum KeyMaterialError: Error, LocalizedError {
    case invalidMasterKey
    case keychain(OSStatus)
    case randomGeneration(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidMasterKey:
            "The database master key must contain at least 32 bytes."
        case let .keychain(status):
            "Keychain operation failed with status \(status)."
        case let .randomGeneration(status):
            "Secure random generation failed with status \(status)."
        }
    }
}

public struct DatabaseKeyMaterial: Sendable {
    let encryptionKey: SymmetricKey
    let identityHMACKey: SymmetricKey

    public init(masterKeyData: Data) throws {
        guard masterKeyData.count >= 32 else {
            throw KeyMaterialError.invalidMasterKey
        }
        let master = SymmetricKey(data: masterKeyData)
        self.encryptionKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            salt: Data("LinkScope.Storage.v1".utf8),
            info: Data("AES-GCM payload".utf8),
            outputByteCount: 32
        )
        self.identityHMACKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            salt: Data("LinkScope.Storage.v1".utf8),
            info: Data("Identity lookup HMAC".utf8),
            outputByteCount: 32
        )
    }

    public func identityDigest(_ value: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: identityHMACKey))
    }
}

public enum KeychainMasterKey {
    public static func loadOrCreate(
        service: String = "cc.jasonstu.linkscope.storage",
        account: String = "database-master-key-v1"
    ) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        guard status == errSecItemNotFound else {
            throw KeyMaterialError.keychain(status)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw KeyMaterialError.randomGeneration(randomStatus)
        }
        let data = Data(bytes)

        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            return try loadOrCreate(service: service, account: account)
        }
        guard addStatus == errSecSuccess else {
            throw KeyMaterialError.keychain(addStatus)
        }
        return data
    }
}

