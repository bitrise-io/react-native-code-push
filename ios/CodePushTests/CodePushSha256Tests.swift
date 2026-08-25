import XCTest

final class CodePushSha256Tests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeFile(named name: String, contents: Data) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try contents.write(to: url)
        return url
    }

    func testHexForFile_matchesExpectedDigest() throws {
        let url = try writeFile(named: "abc.dat", contents: Data("abc".utf8))

        var error: NSError?
        let hex = CodePushSha256HexForFile(url.path, &error)

        XCTAssertNil(error)
        XCTAssertEqual(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testHexForFile_emptyFile_matchesEmptyStringDigest() throws {
        let url = try writeFile(named: "empty.dat", contents: Data())

        var error: NSError?
        let hex = CodePushSha256HexForFile(url.path, &error)

        XCTAssertNil(error)
        XCTAssertEqual(hex, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testHexForFile_missingFile_returnsNilAndSetsError() {
        let missingURL = tempDir.appendingPathComponent("does_not_exist.dat")

        var error: NSError?
        let hex = CodePushSha256HexForFile(missingURL.path, &error)

        XCTAssertNil(hex)
        XCTAssertNotNil(error)
    }
}
