import Foundation
import Security

@objc(CPJWTVerifier)
public final class JWTVerifier: NSObject {
    /// `publicKey` can be PEM-armored or have the armor already removed.
    @objc(verifyAndDecodeJWT:publicKey:error:)
    public static func verifyAndDecode(_ jwt: String, publicKey: String) throws -> [String: Any] {
        let segments = jwt.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ".")
        guard segments.count == 3 else {
            throw JWTVerificationError.malformedToken
        }

        // Pin the algorithm before touching the signature, so a token can't ask
        // to be verified as `none`, or as HS256 with the public key doubling as
        // the HMAC secret.
        guard let headerData = base64URLDecode(segments[0]),
              let headerObject = try? JSONSerialization.jsonObject(with: headerData),
              let header = headerObject as? [String: Any] else {
            throw JWTVerificationError.malformedHeader
        }

        guard let algorithm = header["alg"] as? String else {
            throw JWTVerificationError.missingAlgorithm
        }
        guard algorithm == "RS256" else {
            throw JWTVerificationError.unsupportedAlgorithm(algorithm)
        }

        guard let signature = base64URLDecode(segments[2]), !signature.isEmpty,
              let signedData = "\(segments[0]).\(segments[1])".data(using: .utf8) else {
            throw JWTVerificationError.malformedSignature
        }

        let key = try RSAPublicKey.make(from: publicKey)

        // RFC 8017 8.2.2: the signature is exactly as long as the modulus.
        // SecKeyVerifySignature reports other lengths as errSecParam, which
        // the error mapping below would blame on the key.
        guard signature.count == SecKeyGetBlockSize(key) else {
            throw JWTVerificationError.malformedSignature
        }

        var verificationError: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(key,
                                            .rsaSignatureMessagePKCS1v15SHA256,
                                            signedData as CFData,
                                            signature as CFData,
                                            &verificationError)
        guard isValid else {
            let error = verificationError?.takeRetainedValue()
            // Only errSecVerifyFailed means the signature does not match. Other
            // errors mean the key cannot verify RS256 at all.
            if let error, CFErrorGetCode(error) != CFIndex(errSecVerifyFailed) {
                throw JWTVerificationError.invalidPublicKeyData(reason: error.localizedDescription)
            }
            throw JWTVerificationError.signatureMismatch
        }

        guard let payloadData = base64URLDecode(segments[1]),
              let payloadObject = try? JSONSerialization.jsonObject(with: payloadData),
              let payload = payloadObject as? [String: Any] else {
            throw JWTVerificationError.malformedPayload
        }

        return payload
    }

    /// Decodes an unpadded base64url segment (RFC 7515) into its raw bytes.
    private static func base64URLDecode(_ string: String) -> Data? {
        var normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: normalized)
    }
}
