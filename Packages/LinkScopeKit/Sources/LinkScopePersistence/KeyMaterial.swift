import CryptoKit
import Foundation
import LocalAuthentication
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

public enum KeychainAccessStatus: Sendable, Equatable {
    case available
    case notConfigured
    case authorizationRequired
    case unavailable(OSStatus)
}

public enum KeychainMasterKeyReadResult: Sendable, Equatable {
    case available(Data)
    case notConfigured
    case authorizationRequired
    case unavailable(OSStatus)
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

enum KeychainDomain: Sendable, Equatable {
    case dataProtection
    case legacyFileBased
}

enum KeychainAuthenticationPolicy: Sendable, Equatable {
    case nonInteractive
    case userInitiated(prompt: String?)
}

struct KeychainReadRequest: Sendable, Equatable {
    let service: String
    let account: String
    let domain: KeychainDomain
    let authentication: KeychainAuthenticationPolicy
}

struct KeychainAddRequest: Sendable, Equatable {
    let service: String
    let account: String
    let domain: KeychainDomain
    let data: Data
}

enum KeychainClientReadResult: Sendable, Equatable {
    case data(Data)
    case status(OSStatus)
}

protocol KeychainItemClient: Sendable {
    func read(_ request: KeychainReadRequest) -> KeychainClientReadResult
    func add(_ request: KeychainAddRequest) -> OSStatus
}

struct SystemKeychainItemClient: KeychainItemClient {
    func read(_ request: KeychainReadRequest) -> KeychainClientReadResult {
        let query = Self.readQuery(for: request)
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return .data(data)
        }
        return .status(status)
    }

    func add(_ request: KeychainAddRequest) -> OSStatus {
        SecItemAdd(Self.addAttributes(for: request) as CFDictionary, nil)
    }

    static func readQuery(for request: KeychainReadRequest) -> [CFString: Any] {
        let context = LAContext()
        switch request.authentication {
        case .nonInteractive:
            context.interactionNotAllowed = true
        case let .userInitiated(prompt):
            context.interactionNotAllowed = false
            if let prompt, !prompt.isEmpty {
                context.localizedReason = prompt
            }
        }

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: request.service,
            kSecAttrAccount: request.account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context
        ]
        if request.domain == .dataProtection {
            query[kSecUseDataProtectionKeychain] = true
        }
        return query
    }

    static func addAttributes(for request: KeychainAddRequest) -> [CFString: Any] {
        var attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: request.service,
            kSecAttrAccount: request.account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: request.data
        ]
        if request.domain == .dataProtection {
            attributes[kSecUseDataProtectionKeychain] = true
        }
        return attributes
    }
}

public enum KeychainMasterKey {
    public static func readDataProtectionKeyNonInteractive(
        service: String = "cc.jasonstu.linkscope.storage",
        account: String = "database-master-key-v1"
    ) -> KeychainMasterKeyReadResult {
        readDataProtectionKeyNonInteractive(
            service: service,
            account: account,
            client: SystemKeychainItemClient()
        )
    }

    public static func accessStatus(
        service: String = "cc.jasonstu.linkscope.storage",
        account: String = "database-master-key-v1"
    ) -> KeychainAccessStatus {
        switch readDataProtectionKeyNonInteractive(service: service, account: account) {
        case .available:
            .available
        case .notConfigured:
            .notConfigured
        case .authorizationRequired:
            .authorizationRequired
        case let .unavailable(status):
            .unavailable(status)
        }
    }

    public static func authorizeAndMigrateLegacyKey(
        service: String = "cc.jasonstu.linkscope.storage",
        account: String = "database-master-key-v1",
        operationPrompt: String? = nil
    ) throws -> Data {
        try authorizeAndMigrateLegacyKey(
            service: service,
            account: account,
            operationPrompt: operationPrompt,
            client: SystemKeychainItemClient()
        )
    }

    public static func loadOrCreate(
        service: String = "cc.jasonstu.linkscope.storage",
        account: String = "database-master-key-v1",
        allowAuthenticationUI: Bool = true,
        operationPrompt: String? = nil
    ) throws -> Data {
        if allowAuthenticationUI {
            return try authorizeAndMigrateLegacyKey(
                service: service,
                account: account,
                operationPrompt: operationPrompt
            )
        }

        switch readDataProtectionKeyNonInteractive(service: service, account: account) {
        case let .available(data):
            return data
        case .notConfigured:
            throw KeyMaterialError.keychain(errSecItemNotFound)
        case .authorizationRequired:
            throw KeyMaterialError.keychain(errSecInteractionNotAllowed)
        case let .unavailable(status):
            throw KeyMaterialError.keychain(status)
        }
    }

    static func readDataProtectionKeyNonInteractive(
        service: String,
        account: String,
        client: any KeychainItemClient
    ) -> KeychainMasterKeyReadResult {
        let request = KeychainReadRequest(
            service: service,
            account: account,
            domain: .dataProtection,
            authentication: .nonInteractive
        )
        switch client.read(request) {
        case let .data(data):
            return .available(data)
        case .status(errSecItemNotFound):
            return .notConfigured
        case .status(errSecInteractionNotAllowed),
             .status(errSecAuthFailed),
             .status(errSecUserCanceled):
            return .authorizationRequired
        case let .status(status):
            return .unavailable(status)
        }
    }

    static func authorizeAndMigrateLegacyKey(
        service: String,
        account: String,
        operationPrompt: String?,
        client: any KeychainItemClient
    ) throws -> Data {
        let authentication = KeychainAuthenticationPolicy.userInitiated(prompt: operationPrompt)
        let dataProtectionRequest = KeychainReadRequest(
            service: service,
            account: account,
            domain: .dataProtection,
            authentication: authentication
        )
        switch client.read(dataProtectionRequest) {
        case let .data(data):
            return try validatedMasterKey(data)
        case .status(errSecItemNotFound):
            break
        case let .status(status):
            throw KeyMaterialError.keychain(status)
        }

        let legacyRequest = KeychainReadRequest(
            service: service,
            account: account,
            domain: .legacyFileBased,
            authentication: authentication
        )
        let masterKey: Data
        switch client.read(legacyRequest) {
        case let .data(data):
            masterKey = try validatedMasterKey(data)
        case .status(errSecItemNotFound):
            masterKey = try generateMasterKey()
        case let .status(status):
            throw KeyMaterialError.keychain(status)
        }

        let addRequest = KeychainAddRequest(
            service: service,
            account: account,
            domain: .dataProtection,
            data: masterKey
        )
        switch client.add(addRequest) {
        case errSecSuccess:
            return masterKey
        case errSecDuplicateItem:
            switch client.read(dataProtectionRequest) {
            case let .data(data):
                return try validatedMasterKey(data)
            case let .status(status):
                throw KeyMaterialError.keychain(status)
            }
        case let status:
            throw KeyMaterialError.keychain(status)
        }
    }

    private static func generateMasterKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeyMaterialError.randomGeneration(status)
        }
        return Data(bytes)
    }

    private static func validatedMasterKey(_ data: Data) throws -> Data {
        guard data.count >= 32 else {
            throw KeyMaterialError.invalidMasterKey
        }
        return data
    }
}
