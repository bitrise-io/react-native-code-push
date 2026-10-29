import XCTest
@testable import CodePushCore

/// Fixtures generated with OpenSSL 3.6.3:
///
///   openssl genrsa -out priv.pem 2048
///   openssl rsa -in priv.pem -pubout -out pub.pem
///   printf '%s' "$header.$payload" | openssl dgst -sha256 -sign priv.pem -binary
///
/// where $header and $payload are the unpadded base64url encodings of the JSON
/// below, matching the shape the CodePush CLI emits into `.codepushrelease`.
private enum Fixture {
    static let contentHash = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"

    static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqwrDQSqwFxanoMZWbv5K
    ep3G1jwv8Kg4FMazguXkPX0Efp3hpAbKX+R3LPHTheR+rvoXNo4ioGMWSJjfvYFb
    n4MZCpZJW9vc2LmWUgl3Suy5Rirf7sw/EnIyRbgtP/dtr4VMfoilD7u4sUqqGnwo
    oD6HgT51TbnqNj+pKLJXslp+3qU9lFMVEFjVvYBUmB+tNTDTMJyeQGj0hLvKE18Y
    bIdi2IisPrZNuqNngFgtxlz1LLnKn3kQf/nmJTXtXxnRIyZQiKJI5+4oZvwc/Z9u
    55/jNqQr1M526fbtoUbbj0TGiqyoc6sNr3KRgJgy4QTz4d737JJgp6B+1a8IWny1
    HwIDAQAB
    -----END PUBLIC KEY-----
    """

    /// `publicKeyPEM` as a bare PKCS#1 RSAPublicKey:
    /// `openssl rsa -pubin -in pub.pem -RSAPublicKey_out`
    static let pkcs1PublicKeyPEM = """
    -----BEGIN RSA PUBLIC KEY-----
    MIIBCgKCAQEAqwrDQSqwFxanoMZWbv5Kep3G1jwv8Kg4FMazguXkPX0Efp3hpAbK
    X+R3LPHTheR+rvoXNo4ioGMWSJjfvYFbn4MZCpZJW9vc2LmWUgl3Suy5Rirf7sw/
    EnIyRbgtP/dtr4VMfoilD7u4sUqqGnwooD6HgT51TbnqNj+pKLJXslp+3qU9lFMV
    EFjVvYBUmB+tNTDTMJyeQGj0hLvKE18YbIdi2IisPrZNuqNngFgtxlz1LLnKn3kQ
    f/nmJTXtXxnRIyZQiKJI5+4oZvwc/Z9u55/jNqQr1M526fbtoUbbj0TGiqyoc6sN
    r3KRgJgy4QTz4d737JJgp6B+1a8IWny1HwIDAQAB
    -----END RSA PUBLIC KEY-----
    """

    /// A different keypair, used to prove verification is actually key-bound.
    static let otherPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoea7a3ZjWgjQntjnYdm4
    hfZCsE0CsgXxIUz9Dto/0IyS2iA6VgEl1f/Ghd9n9DlWVoMyZC77yWubtt3bKl7n
    DcoX+3JZPFjV4w0tqdR2Ly/XBKxRDqMKYinFKaWuvjlWiQpjum+eE+vSddHko23P
    +J6KcYT0rlpcfKTy4U3sr8OuB3zNwISy2x0H9Wos2xrCdY6DlANeH5RdeypV59Xi
    0Bm7aeX4WIfx3v7z2v+0EE6nOVy0rWqaFoRaqMT2CKBpez4Rz7Xmlhwb4HFEY09n
    UKltxIPLyPlfFat+rPzdZsAMLNoE2e92HHBbbAcAKYlhqXRXka2UfGPjc8wmzUo5
    BwIDAQAB
    -----END PUBLIC KEY-----
    """

    static let validToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbGFpbXMiOnsiY29udGVudEhhc2giOiJhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MGExYjJjM2Q0ZTVmNjA3MTgyOTNhNGI1YzZkN2U4ZjkwIn0sImNvbnRlbnRIYXNoIjoiYTFiMmMzZDRlNWY2MDcxODI5M2E0YjVjNmQ3ZThmOTBhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MCJ9.Q-TCO7SgF3OFtI1o3-Jz079qZ9r7d0YVvD4mCQzd6JCX8Lij5E7JygKDp0CM9YLqxaFCzABYoZedrQaJCWhwygsedHuGOLxWRKk-3oNEIlzcNZJSDUv8bWlwR5Sj1Ujme7m05jRdkPtowxr9rkv38_Pexesq8ZJu2SiDNO9Yzl6K6R12xxQt5kqN9DyPi1l11zVPW-rLmkOTy55hsBOcbVHlCJqz7XEHWVr0OLKCqxWI2K86ADiE5mPdi-8JgXhh39Yk88PPWCNMHYPyblKRcv20PL0uR2MV25OgMca8yx3gSAF2NHxucA7PkAY2qutaFIt5GKc_xNLXkUvZy2QIHQ"

    /// Header claims `none`, signature segment left empty.
    static let algNoneToken = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJjbGFpbXMiOnsiY29udGVudEhhc2giOiJhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MGExYjJjM2Q0ZTVmNjA3MTgyOTNhNGI1YzZkN2U4ZjkwIn0sImNvbnRlbnRIYXNoIjoiYTFiMmMzZDRlNWY2MDcxODI5M2E0YjVjNmQ3ZThmOTBhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MCJ9."

    /// Signed with HMAC-SHA256 using the PEM public key as the shared secret.
    /// This is the classic algorithm-confusion attack against RSA-verifying servers.
    static let hs256Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbGFpbXMiOnsiY29udGVudEhhc2giOiJhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MGExYjJjM2Q0ZTVmNjA3MTgyOTNhNGI1YzZkN2U4ZjkwIn0sImNvbnRlbnRIYXNoIjoiYTFiMmMzZDRlNWY2MDcxODI5M2E0YjVjNmQ3ZThmOTBhMWIyYzNkNGU1ZjYwNzE4MjkzYTRiNWM2ZDdlOGY5MCJ9.q1ASbgJepaqy24fiO4_uVpLoBv36uHdxAuPB3rtrook"

    /// A PKCS#1 RSA private key (`openssl genrsa -traditional`). Its DER also
    /// starts with SEQUENCE { INTEGER, INTEGER, ... }, same as a PKCS#1
    /// RSAPublicKey, so it must not be misread as one.
    static let privateKeyPEM = """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEogIBAAKCAQEA2VhJhyOAIW3x8L8shzQ8g9vtWFxmJCaAAVWOZEJQxiLg9nuk
    cNFBgm/aqUo6/mgy0GWzTE9v2k75eghKlo5wlIRs0P672PrfosuMweFCftcDv8w0
    aEyzF4+D7VpCUSmc5J1J9oCAzNdQDSh//COf3buLALDxKQddLwCYp8dVHpM5XtdE
    Cex4VHgDOqlWCwI4yxIX8B/LZmwj9aDYIRXsJz54p/6TN9H0vdSr+963iwnd1MM4
    pM14ASQvY8YZt05yrWcuMVQmasyhiiSJwFbySQBa6qXOemB5NKcloBH9Xo/+O0nN
    0LrxMuWNfKp1VhNvjbOkE62yi6ETvDfId/fY/QIDAQABAoIBAELxuKQRQTQKw0yd
    9b8nTcRnhzGCNEvKN/8xNQyYiHye3Z/N8ZZ2PbFJdpZSMN2Phqc9y/4jMZaSYLE/
    wImjEfYM2997tqxciWmBPLezBGJBI/x9j17Y0QjewYnoFSkeoh6ge9mbNxDg+N00
    rkchSepoC6aI2Z8Dj6YcjuiOsx8ZNAFIP1hkSH3UxHAu1i967nBCEjIip6UqomuJ
    V4iaYia6ZRNIZIBBOFzMwqlQudvu/1Xm2UTQ/E3sZ0DMaMv+8S3KZ2hZjagtYETI
    25jxwi4WDcUfi7LV8UOjAl3On5C/4WITk3xOUJegpwF4wQBOYTGBfliexB4XQGpD
    QW+4XdkCgYEA/ufPgKRLaKd/KJ5Dy01LslEcHNB9/zyMWjxkVYAUOLG/JhkssP8/
    98PeGzybVcUejySAiRlpM9g5pKN2MvCYmCgQAdAjPn2wv1iPpAJqNPLDGH2ninIp
    GjaIoaaIrZineimytwIYPqz2y2U5KqUWMKCdw9VfQCeRmA2cpPhKygcCgYEA2kcw
    vmRkGZ3wyOUMdWFmGMLzyzvGgI4vibpN/3jHvASYQgZKpRxRdDz8e2o5oJD5MNlS
    mXtiORBuSyxrElI93c8UTGEtyT0yGMzyqekTyTwPgSLjUZJakz+BIZO2V0NxOg6I
    yg6OPhPHQhpJT9opvaWMyOguYJMK9j9jd99tk9sCgYBTQigWnpM65aq0+6ytFNwq
    rC+AgeEFoyM8vgkPnDv+oKAMs6BTV6vvI3zCbLNX+oCWxJdvMGuaUX/SdMnArbFJ
    0ZwY24EHgkpe1XBlY5yJGtn6f+BfahZex30tP5XZDcl2L3R+LiL5JcmeebuIYE+1
    JmEhe+oWrFXz0k5d2/OhtQKBgE1FJlw/7a+j2blEXESxVhMt8F/hqUOZEfsPmMz3
    VL2aYsv8rjAE9lDPxhFqaTwOFijUxgjPRNYumtzBvKWft4bt56GiRTMYFsPwyXac
    rARw3ow4bYBS7v1xXaUlRUde+JY0zve4b2JKXh9obst1z5DzKgN1LfXCF/9UMUIe
    NgxBAoGAE1zIkL2VT5subX6AaBp/jEOhZJv3KMY0tNLPV90dZqyS7OdwMNMG5fr4
    RjCOriggOMmgWDyQvVtJia/F83/77EOniEzlbF2jsOe9GdsIFF23WZkvaWopUqD3
    azYmUTYxq+xJH+OBbKqZ8vratPhdqIfIFgtE7ON7cYYmUVJ7ub0=
    -----END RSA PRIVATE KEY-----
    """

    /// `openssl ecparam -name prime256v1 -genkey -noout | openssl ec -pubout`
    static let ecPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEtIGNT+Gnne5Fimk02xR54AP5XKwi
    5A/mS+iuwhT/7Kr/JkOk3kplfXvEzj8jWRrn2zmKfCuUpNnHGdQ5/+r3cg==
    -----END PUBLIC KEY-----
    """

    /// `openssl genpkey -algorithm rsa-pss | openssl pkey -pubout`
    static let rsaPSSPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIDALBgkqhkiG9w0BAQoDggEPADCCAQoCggEBALcbbE7nAICNa+ovaoVfASCd
    1ZjEd6E8VnAZ82VMq7qcLBGN+JSCh+ztdDuqAGsbc3MG5C7RNCAnOTBgYJ+u/qvx
    7USd69kPsLSwg4H95+wi6oTPXmeVi1m3AoLCuYxKgsvMzi546DQHUDOSYnwFgEaW
    4e4kNv/L4ojJ0bedzZ1B1zYpEJZlxANt7EyMo5MgQI2k6uzduD2GE7C4vWglCsp1
    0FTFBluPMrHulOZyQN6lHmgcT4XxxPO72VpqnL5Cl0YZeJowPGtGMKgUWZFENjDP
    EEqQeyTAbYb+kxX6xi6z00T0TF5CefD9Go74ftHPHbNQIH73wz3i1g1W5VwaamEC
    AwEAAQ==
    -----END PUBLIC KEY-----
    """

    /// What `+[CodePushUpdateUtils getKeyValueFromPublicKeyString:]` passes
    /// to the verifier.
    static var strippedPublicKey: String {
        publicKeyPEM
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----\n", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

final class JWTVerifierTests: XCTestCase {
    func testVerifiesGenuineTokenAndReturnsPayload() throws {
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: Fixture.publicKeyPEM)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testAcceptsPublicKeyWithPEMArmorAlreadyStripped() throws {
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: Fixture.strippedPublicKey)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testAcceptsPKCS1PublicKey() throws {
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: Fixture.pkcs1PublicKeyPEM)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testAcceptsPKCS1PublicKeyOnOneLine() throws {
        // getKeyValueFromPublicKeyString: removes every newline but keeps the
        // `RSA PUBLIC KEY` markers.
        let key = Fixture.pkcs1PublicKeyPEM.replacingOccurrences(of: "\n", with: "")
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: key)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testAcceptsIndentedPEM() throws {
        let key = Fixture.publicKeyPEM
            .components(separatedBy: "\n")
            .map { "    \($0)" }
            .joined(separator: "\n")
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: key)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testAcceptsTokenWithTrailingNewline() throws {
        let payload = try JWTVerifier.verifyAndDecode(Fixture.validToken + "\r\n", publicKey: Fixture.publicKeyPEM)

        XCTAssertEqual(payload["contentHash"] as? String, Fixture.contentHash)
    }

    func testRejectsTamperedPayload() {
        let segments = Fixture.validToken.components(separatedBy: ".")
        let forged = base64URLEncode(#"{"contentHash":"0000000000000000000000000000000000000000000000000000000000000000"}"#)
        let tampered = "\(segments[0]).\(forged).\(segments[2])"

        assertThrows(.signatureMismatch) {
            try JWTVerifier.verifyAndDecode(tampered, publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsTokenSignedByADifferentKey() {
        assertThrows(.signatureMismatch) {
            try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: Fixture.otherPublicKeyPEM)
        }
    }

    func testRejectsHeaderWithoutAlgorithm() {
        let segments = Fixture.validToken.components(separatedBy: ".")
        let header = base64URLEncode(#"{"typ":"JWT"}"#)

        assertThrows(.missingAlgorithm) {
            try JWTVerifier.verifyAndDecode("\(header).\(segments[1]).\(segments[2])", publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsAlgNone() {
        assertThrows(.unsupportedAlgorithm("none")) {
            try JWTVerifier.verifyAndDecode(Fixture.algNoneToken, publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsHS256SignedWithThePublicKeyAsSecret() {
        assertThrows(.unsupportedAlgorithm("HS256")) {
            try JWTVerifier.verifyAndDecode(Fixture.hs256Token, publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsTokenWithWrongSegmentCount() {
        let segments = Fixture.validToken.components(separatedBy: ".")

        assertThrows(.malformedToken) {
            try JWTVerifier.verifyAndDecode("\(segments[0]).\(segments[1])", publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsEmptySignatureSegment() {
        let segments = Fixture.validToken.components(separatedBy: ".")

        assertThrows(.malformedSignature) {
            try JWTVerifier.verifyAndDecode("\(segments[0]).\(segments[1]).", publicKey: Fixture.publicKeyPEM)
        }
    }

    func testRejectsSignatureOfWrongLength() {
        let segments = Fixture.validToken.components(separatedBy: ".")

        for signature in [String(segments[2].dropLast(4)), segments[2] + "AAAA"] {
            assertThrows(.malformedSignature) {
                try JWTVerifier.verifyAndDecode("\(segments[0]).\(segments[1]).\(signature)", publicKey: Fixture.publicKeyPEM)
            }
        }
    }

    func testRejectsEmptyPublicKeyBody() {
        assertThrows(.malformedPublicKey) {
            try JWTVerifier.verifyAndDecode(Fixture.validToken,
                                            publicKey: "-----BEGIN PUBLIC KEY-----\n-----END PUBLIC KEY-----")
        }
    }

    func testRejectsUnparseablePublicKey() {
        assertThrows(.malformedPublicKey) {
            try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: "not a key")
        }
    }

    // The tests below pin the Security framework behavior that
    // RSAPublicKey relies on: SecKeyCreateWithData rejects everything that is
    // not RSA public key material.

    func testRejectsPrivateKeyConfiguredAsPublicKey() {
        assertRejectsAsInvalidKeyData(Fixture.privateKeyPEM)
    }

    func testRejectsECPublicKey() {
        assertRejectsAsInvalidKeyData(Fixture.ecPublicKeyPEM)
    }

    func testRejectsMalformedRSAKeyData() {
        let truncated = Data(base64Encoded: Fixture.strippedPublicKey)!.dropLast(10).base64EncodedString()
        // SEQUENCE { INTEGER 2, INTEGER 3 }: the PKCS#1 RSAPublicKey shape,
        // but not usable RSA key material.
        let unusable = "MAYCAQICAQM="

        for key in [Fixture.rsaPSSPublicKeyPEM, truncated, unusable] {
            assertRejectsAsInvalidKeyData(key)
        }
    }

    private func base64URLEncode(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func assertRejectsAsInvalidKeyData(_ key: String,
                                               file: StaticString = #filePath,
                                               line: UInt = #line) {
        do {
            _ = try JWTVerifier.verifyAndDecode(Fixture.validToken, publicKey: key)
            XCTFail("Expected invalidPublicKeyData but verification succeeded", file: file, line: line)
        } catch JWTVerificationError.invalidPublicKeyData {
            // The Security framework's message isn't a stable, documented
            // string, so only the case is asserted, not its associated reason.
        } catch {
            XCTFail("Expected invalidPublicKeyData but got \(error)", file: file, line: line)
        }
    }

    private func assertThrows(_ expected: JWTVerificationError,
                              file: StaticString = #filePath,
                              line: UInt = #line,
                              _ body: () throws -> [String: Any]) {
        do {
            _ = try body()
            XCTFail("Expected \(expected) but verification succeeded", file: file, line: line)
        } catch let error as JWTVerificationError {
            XCTAssertEqual(String(describing: error), String(describing: expected), file: file, line: line)
        } catch {
            XCTFail("Expected \(expected) but got \(error)", file: file, line: line)
        }
    }
}
