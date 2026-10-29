import Foundation
import Security

enum RSAPublicKey {
    /// Builds a `SecKey` from a public key in either PEM-armored or bare-base64
    /// form. `SecKeyCreateWithData` accepts both the X.509 SubjectPublicKeyInfo
    /// that CodePush distributes and a bare PKCS#1 RSAPublicKey, so the DER is
    /// passed through as is. See "Importing Cryptographic Keys" by Eskimo:
    /// https://developer.apple.com/forums/thread/680572
    static func make(from string: String) throws -> SecKey {
        guard let der = derBytes(from: string) else {
            throw JWTVerificationError.malformedPublicKey
        }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]

        var creationError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData,
                                             attributes as CFDictionary,
                                             &creationError) else {
            let reason = creationError?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw JWTVerificationError.invalidPublicKeyData(reason: reason)
        }

        return key
    }

    private static func derBytes(from string: String) -> Data? {
        // Not line by line: the `CodePushPublicKey` Info.plist value can have
        // the armor and the base64 body on one line.
        let body = string
            .replacingOccurrences(of: "-----[^-]+-----", with: "", options: .regularExpression)
            .filter { !$0.isWhitespace }

        // Data(base64Encoded: "") is empty Data, not nil.
        guard !body.isEmpty else {
            return nil
        }

        return Data(base64Encoded: body)
    }
}
