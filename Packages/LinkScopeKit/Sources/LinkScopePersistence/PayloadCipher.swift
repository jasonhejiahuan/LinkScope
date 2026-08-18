import CryptoKit
import Foundation

enum PayloadCipher {
    static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw PayloadCipherError.missingCombinedRepresentation
        }
        return combined
    }

    static func open(_ ciphertext: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }
}

enum PayloadCipherError: Error {
    case missingCombinedRepresentation
}

