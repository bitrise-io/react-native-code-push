import XCTest

final class CodePushBinaryDiffPatcherTests: XCTestCase {

    private var tempDir: URL!
    private var currentPackageFolder: URL!
    private var unzippedFolder: URL!
    private var newUpdateFolder: URL!

    private let relativePath = "main.jsbundle"
    private let patchRelativePath = "__hcp_patches/main.jsbundle.bsdiff"

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        currentPackageFolder = tempDir.appendingPathComponent("current")
        unzippedFolder = tempDir.appendingPathComponent("unzipped")
        newUpdateFolder = tempDir.appendingPathComponent("new")

        let scratchDirs: [URL] = [currentPackageFolder, unzippedFolder, newUpdateFolder]
        for dir in scratchDirs {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try FileManager.default.createDirectory(
            at: unzippedFolder.appendingPathComponent("__hcp_patches"),
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func fixtureURL(_ relativePath: String) -> URL {
        let bundle = Bundle(for: type(of: self))
        guard let resourceURL = bundle.url(forResource: "Fixtures", withExtension: nil) else {
            fatalError("Fixtures resource folder not found in test bundle")
        }
        return resourceURL.appendingPathComponent(relativePath)
    }

    private func hashOfFixture(_ relativePath: String) throws -> String {
        var error: NSError?
        guard let hex = CodePushSha256HexForFile(fixtureURL(relativePath).path, &error) else {
            throw error ?? NSError(domain: "test", code: 1)
        }
        return hex
    }

    private func installBasicFixtures() throws {
        try FileManager.default.copyItem(
            at: fixtureURL("basic/old.dat"),
            to: currentPackageFolder.appendingPathComponent(relativePath))
        try FileManager.default.copyItem(
            at: fixtureURL("basic/patch.bsdiff"),
            to: unzippedFolder.appendingPathComponent(patchRelativePath))
    }

    private func manifest(baseHash: String, targetHash: String, algo: String = "bsdiff", patchPath: String? = nil, relativePath: String? = nil) -> CodePushDiffManifest {
        let entry = CodePushPatchedFileEntry(
            algo: algo,
            baseHash: baseHash,
            targetHash: targetHash,
            patch: patchPath ?? patchRelativePath)
        return CodePushDiffManifest(
            version: 2,
            deletedFiles: [],
            patchedFiles: [relativePath ?? self.relativePath: entry])
    }

    func testApply_happyPath_producesExpectedOutputFile() throws {
        try installBasicFixtures()
        let baseHash = try hashOfFixture("basic/old.dat")
        let targetHash = try hashOfFixture("basic/new.dat")

        try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
            manifest: manifest(baseHash: baseHash, targetHash: targetHash),
            currentPackageFolder: currentPackageFolder.path,
            unzippedFolder: unzippedFolder.path,
            newUpdateFolder: newUpdateFolder.path)

        let producedData = try Data(contentsOf: newUpdateFolder.appendingPathComponent(relativePath))
        let expectedData = try Data(contentsOf: fixtureURL("basic/new.dat"))
        XCTAssertEqual(producedData, expectedData)
    }

    func testApply_baseHashMismatch_throws() throws {
        try installBasicFixtures()
        let targetHash = try hashOfFixture("basic/new.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: "not-the-real-hash", targetHash: targetHash),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }

    func testApply_targetHashMismatch_throws() throws {
        try installBasicFixtures()
        let baseHash = try hashOfFixture("basic/old.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: baseHash, targetHash: "not-the-real-hash"),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }

    func testApply_unsupportedAlgo_throwsWithoutTouchingFiles() {
        // No fixtures installed: an unsupported algo must be rejected before any file I/O.
        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: "irrelevant", targetHash: "irrelevant", algo: "xdelta"),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }

    func testApply_pathTraversalInPatchedFilesKey_isRejected() throws {
        try installBasicFixtures()
        let baseHash = try hashOfFixture("basic/old.dat")
        let targetHash = try hashOfFixture("basic/new.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: baseHash, targetHash: targetHash, relativePath: "../../etc/passwd"),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }

    func testApply_pathTraversalInManifestPatchField_isRejected() throws {
        try installBasicFixtures()
        let baseHash = try hashOfFixture("basic/old.dat")
        let targetHash = try hashOfFixture("basic/new.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: baseHash, targetHash: targetHash, patchPath: "../../../etc/passwd"),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }

    // The update zip is extracted before anything verifies it, so it can plant a
    // symlink in the new update folder and patch through it.
    func testApply_outputPathThroughSymlink_isRejectedAndWritesNothing() throws {
        let nestedRelativePath = "escape/main.jsbundle"
        try FileManager.default.createDirectory(
            at: currentPackageFolder.appendingPathComponent("escape"),
            withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: fixtureURL("basic/old.dat"),
            to: currentPackageFolder.appendingPathComponent(nestedRelativePath))
        try FileManager.default.copyItem(
            at: fixtureURL("basic/patch.bsdiff"),
            to: unzippedFolder.appendingPathComponent(patchRelativePath))

        let outsideFolder = tempDir.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outsideFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: newUpdateFolder.appendingPathComponent("escape"),
            withDestinationURL: outsideFolder)

        let baseHash = try hashOfFixture("basic/old.dat")
        let targetHash = try hashOfFixture("basic/new.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: baseHash, targetHash: targetHash, relativePath: nestedRelativePath),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: outsideFolder.appendingPathComponent("main.jsbundle").path))
    }

    func testApply_corruptPatchFile_throws() throws {
        try FileManager.default.copyItem(
            at: fixtureURL("basic/old.dat"),
            to: currentPackageFolder.appendingPathComponent(relativePath))
        try Data([0x00, 0x01, 0x02, 0x03]).write(
            to: unzippedFolder.appendingPathComponent(patchRelativePath))
        let baseHash = try hashOfFixture("basic/old.dat")

        XCTAssertThrowsError(
            try CodePushBinaryDiffPatcher.applyBinaryDiffPatches(
                manifest: manifest(baseHash: baseHash, targetHash: "irrelevant-not-reached-on-failure"),
                currentPackageFolder: currentPackageFolder.path,
                unzippedFolder: unzippedFolder.path,
                newUpdateFolder: newUpdateFolder.path))
    }
}
