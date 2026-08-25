import Foundation
import LocalAuthentication
import Security
import Testing
@testable import LinkScopePersistence

private final class RecordingKeychainClient: KeychainItemClient, @unchecked Sendable {
    var queuedReads: [KeychainClientReadResult]
    var queuedAddStatuses: [OSStatus]
    private(set) var readRequests: [KeychainReadRequest] = []
    private(set) var addRequests: [KeychainAddRequest] = []

    init(
        queuedReads: [KeychainClientReadResult],
        queuedAddStatuses: [OSStatus] = []
    ) {
        self.queuedReads = queuedReads
        self.queuedAddStatuses = queuedAddStatuses
    }

    func read(_ request: KeychainReadRequest) -> KeychainClientReadResult {
        readRequests.append(request)
        guard !queuedReads.isEmpty else { return .status(errSecItemNotFound) }
        return queuedReads.removeFirst()
    }

    func add(_ request: KeychainAddRequest) -> OSStatus {
        addRequests.append(request)
        guard !queuedAddStatuses.isEmpty else { return errSecSuccess }
        return queuedAddStatuses.removeFirst()
    }
}

@Test func dataProtectionQueriesAreExplicitlyNonInteractive() throws {
    let request = KeychainReadRequest(
        service: "test.service",
        account: "test.account",
        domain: .dataProtection,
        authentication: .nonInteractive
    )
    let query = SystemKeychainItemClient.readQuery(for: request)
    let context = try #require(query[kSecUseAuthenticationContext] as? LAContext)

    #expect(query[kSecUseDataProtectionKeychain] as? Bool == true)
    #expect(query[kSecReturnData] as? Bool == true)
    #expect(context.interactionNotAllowed)
}

@Test func legacyMigrationQueriesAllowUIOnlyAfterExplicitAction() throws {
    let request = KeychainReadRequest(
        service: "test.service",
        account: "test.account",
        domain: .legacyFileBased,
        authentication: .userInitiated(prompt: "Test migration")
    )
    let query = SystemKeychainItemClient.readQuery(for: request)
    let context = try #require(query[kSecUseAuthenticationContext] as? LAContext)

    #expect(query[kSecUseDataProtectionKeychain] == nil)
    #expect(!context.interactionNotAllowed)
    #expect(context.localizedReason == "Test migration")
}

@Test func dataProtectionAddsUseDeviceOnlyAfterFirstUnlockAccessibility() {
    let request = KeychainAddRequest(
        service: "test.service",
        account: "test.account",
        domain: .dataProtection,
        data: Data(repeating: 0x41, count: 32)
    )
    let attributes = SystemKeychainItemClient.addAttributes(for: request)

    #expect(attributes[kSecUseDataProtectionKeychain] as? Bool == true)
    #expect(
        attributes[kSecAttrAccessible] as? String
            == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
}

@Test func launchReadNeverFallsBackToLegacyKeychain() {
    let client = RecordingKeychainClient(queuedReads: [.status(errSecItemNotFound)])

    let result = KeychainMasterKey.readDataProtectionKeyNonInteractive(
        service: "test.service",
        account: "test.account",
        client: client
    )

    #expect(result == .notConfigured)
    #expect(client.readRequests.count == 1)
    #expect(client.readRequests.first?.domain == .dataProtection)
    #expect(client.readRequests.first?.authentication == .nonInteractive)
}

@Test func explicitAuthorizationMigratesTheSameLegacyMasterKey() throws {
    let legacyKey = Data(repeating: 0x5A, count: 32)
    let client = RecordingKeychainClient(
        queuedReads: [.status(errSecItemNotFound), .data(legacyKey)],
        queuedAddStatuses: [errSecSuccess]
    )

    let migrated = try KeychainMasterKey.authorizeAndMigrateLegacyKey(
        service: "test.service",
        account: "test.account",
        operationPrompt: "Test migration",
        client: client
    )

    #expect(migrated == legacyKey)
    #expect(client.readRequests.map(\.domain) == [.dataProtection, .legacyFileBased])
    #expect(client.addRequests.count == 1)
    #expect(client.addRequests.first?.domain == .dataProtection)
    #expect(client.addRequests.first?.data == legacyKey)
}

@Test func cancelingLegacyAuthorizationLeavesDataProtectionUnchanged() {
    let client = RecordingKeychainClient(
        queuedReads: [.status(errSecItemNotFound), .status(errSecUserCanceled)]
    )

    do {
        _ = try KeychainMasterKey.authorizeAndMigrateLegacyKey(
            service: "test.service",
            account: "test.account",
            operationPrompt: "Test migration",
            client: client
        )
        Issue.record("Expected cancellation to be reported")
    } catch let KeyMaterialError.keychain(status) {
        #expect(status == errSecUserCanceled)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(client.addRequests.isEmpty)
}

@Test func freshExplicitSetupCreatesOnlyADataProtectionKey() throws {
    let client = RecordingKeychainClient(
        queuedReads: [.status(errSecItemNotFound), .status(errSecItemNotFound)],
        queuedAddStatuses: [errSecSuccess]
    )

    let key = try KeychainMasterKey.authorizeAndMigrateLegacyKey(
        service: "test.service",
        account: "test.account",
        operationPrompt: "Test setup",
        client: client
    )

    #expect(key.count == 32)
    #expect(client.addRequests.count == 1)
    #expect(client.addRequests.first?.domain == .dataProtection)
    #expect(client.addRequests.first?.data == key)
}
