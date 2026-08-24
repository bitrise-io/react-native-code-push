import XCTest

final class BSPatchTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
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

    private func outputURL(_ name: String) -> URL {
        tempDir.appendingPathComponent(name)
    }

    private func applyPatch(oldFile: URL, diffFile: URL, outFile: URL) -> CodePushBSPatchResult {
        oldFile.path.withCString { oldPath in
            diffFile.path.withCString { diffPath in
                outFile.path.withCString { outPath in
                    codepush_bspatch_apply(oldPath, diffPath, outPath)
                }
            }
        }
    }

    // An ordinary text-file diff, several inserted/changed/copied regions.
    func testApplyPatch_basicDiff_succeedsAndMatchesExpectedOutput() throws {
        let oldFile = fixtureURL("basic/old.dat")
        let diffFile = fixtureURL("basic/patch.bsdiff")
        let expectedNewFile = fixtureURL("basic/new.dat")
        let outFile = outputURL("basic_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_OK)
        XCTAssertEqual(try Data(contentsOf: outFile), try Data(contentsOf: expectedNewFile))
    }

    // Real BSDIFF40 patch whose only control entry is a single full-length copy from the old file.
    func testApplyPatch_identicalOldAndNew_succeeds() throws {
        let oldFile = fixtureURL("identical/old.dat")
        let diffFile = fixtureURL("identical/patch.bsdiff")
        let expectedNewFile = fixtureURL("identical/new.dat")
        let outFile = outputURL("identical_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_OK)
        XCTAssertEqual(try Data(contentsOf: outFile), try Data(contentsOf: expectedNewFile))
    }

    func testApplyPatch_emptyOldFile_succeeds() throws {
        let oldFile = fixtureURL("empty_old/old.dat")
        let diffFile = fixtureURL("empty_old/patch.bsdiff")
        let expectedNewFile = fixtureURL("empty_old/new.dat")
        let outFile = outputURL("empty_old_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_OK)
        XCTAssertEqual(try Data(contentsOf: outFile), try Data(contentsOf: expectedNewFile))
    }

    // Well-formed length, wrong magic bytes (hand-written, not a real bsdiff output).
    func testApplyPatch_badDiffHeader_returnsBadDiffHeader() {
        let oldFile = fixtureURL("bad_header/old.dat")
        let diffFile = fixtureURL("bad_header/patch.bsdiff")
        let outFile = outputURL("bad_header_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_ERR_BAD_DIFF_HEADER)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outFile.path),
                        "output file should not be left behind after a failed patch")
    }

    // HDiffPatch's bounds checks must reject these inputs rather than reading out of range or
    // silently emitting corrupt output. wrong_old/old.dat is unrelated to (and shorter than)
    // basic/old.dat, so basic/patch.bsdiff's copy instructions reference offsets out of range for it.
    func testApplyPatch_mismatchedOldFile_returnsPatchFailed() {
        let oldFile = fixtureURL("wrong_old/old.dat")
        let diffFile = fixtureURL("basic/patch.bsdiff")
        let outFile = outputURL("mismatched_old_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_ERR_PATCH_FAILED)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outFile.path),
                        "output file should not be left behind after a failed patch")
    }

    func testApplyPatch_missingOldFile_returnsOpenOldFailed() {
        let missingOldFile = outputURL("does_not_exist_old.dat")
        let diffFile = fixtureURL("basic/patch.bsdiff")
        let outFile = outputURL("missing_old_out.dat")

        let result = applyPatch(oldFile: missingOldFile, diffFile: diffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_ERR_OPEN_OLD)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outFile.path),
                        "output file should not be left behind after a failed patch")
    }

    func testApplyPatch_missingDiffFile_returnsOpenDiffFailed() {
        let oldFile = fixtureURL("basic/old.dat")
        let missingDiffFile = outputURL("does_not_exist.bsdiff")
        let outFile = outputURL("missing_diff_out.dat")

        let result = applyPatch(oldFile: oldFile, diffFile: missingDiffFile, outFile: outFile)

        XCTAssertEqual(result, CODEPUSH_BSPATCH_ERR_OPEN_DIFF)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outFile.path),
                        "output file should not be left behind after a failed patch")
    }
}
