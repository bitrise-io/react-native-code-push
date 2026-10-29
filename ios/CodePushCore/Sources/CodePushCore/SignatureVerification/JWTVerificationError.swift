import Foundation

public enum JWTVerificationError: Error, LocalizedError {
    case malformedToken
    case malformedHeader
    case missingAlgorithm
    case unsupportedAlgorithm(String)
    case malformedPayload
    case malformedSignature
    case malformedPublicKey
    case invalidPublicKeyData(reason: String)
    case signatureMismatch

    public var errorDescription: String? {
        switch self {
        case .malformedToken:
            return "The signature is not a well-formed JWT: expected three '.'-separated segments."
        case .malformedHeader:
            return "The JWT header could not be decoded as a JSON object."
        case .missingAlgorithm:
            return "The JWT header has no \"alg\" field. CodePush release signatures must use RS256."
        case .unsupportedAlgorithm(let algorithm):
            return "Unsupported JWT algorithm \"\(algorithm)\". CodePush release signatures must use RS256."
        case .malformedPayload:
            return "The JWT payload could not be decoded as a JSON object."
        case .malformedSignature:
            return "The JWT signature segment is empty, is not valid base64url, or does not have the length of the key."
        case .malformedPublicKey:
            return "The configured public key could not be parsed as an RSA public key."
        case .invalidPublicKeyData(let reason):
            return "The configured public key is not a valid RSA public key: \(reason)"
        case .signatureMismatch:
            return "The JWT signature was not produced by the configured public key."
        }
    }
}
