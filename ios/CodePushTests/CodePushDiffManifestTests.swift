import XCTest

final class CodePushDiffManifestTests: XCTestCase {

    func testManifest_missingVersionField_defaultsToOne() throws {
        let manifest = try CodePushDiffManifest(json: [:])

        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.deletedFiles, [])
        XCTAssertEqual(manifest.patchedFiles.count, 0)
    }

    func testManifest_deletedFilesAndPatchedFiles_areParsed() throws {
        let json: [AnyHashable: Any] = [
            "version": 2,
            "deletedFiles": ["assets/old.png"],
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]

        let manifest = try CodePushDiffManifest(json: json)

        XCTAssertEqual(manifest.version, 2)
        XCTAssertEqual(manifest.deletedFiles, ["assets/old.png"])

        let entry = manifest.patchedFiles["main.jsbundle"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.algo, "bsdiff")
        XCTAssertEqual(entry?.baseHash, "aaaa")
        XCTAssertEqual(entry?.targetHash, "bbbb")
        XCTAssertEqual(entry?.patch, "__hcp_patches/main.jsbundle.bsdiff")
    }

    func testManifest_patchedFilesEntryMissingRequiredField_throws() {
        let json: [AnyHashable: Any] = [
            "version": 2,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    // targetHash is missing.
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json)) { error in
            // The message has to name the one field that is wrong, not the set
            // of fields an entry needs.
            XCTAssertTrue(error.localizedDescription.contains("targetHash"), error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.contains("baseHash"), error.localizedDescription)
        }
    }

    // A version that is not a number must not fall back to 1: that would skip
    // every patch of a version 2 manifest and install the old bytes.
    func testManifest_nonNumericVersion_throws() {
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": "2"]))
    }

    func testManifest_patchedFilesWithoutVersionTwo_throws() {
        let json: [AnyHashable: Any] = [
            "version": 1,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json))
    }

    // A container of the wrong type must not parse as an empty one: that would
    // skip the deletions or patches it describes and install the old bytes
    // under the new package hash.
    func testManifest_wrongTypedContainers_throw() {
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["deletedFiles": "assets/old.png"]))
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["deletedFiles": [42]]))
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": 2, "patchedFiles": [["algo": "bsdiff"]]]))
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": 2, "patchedFiles": ["main.jsbundle": "bsdiff"]]))
    }

    // Matches Android, which rejects any version other than 2 that lists patches.
    func testManifest_patchedFilesOnUnknownVersion_throws() {
        let json: [AnyHashable: Any] = [
            "version": 3,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json))
    }

    // MARK: - resolvePath(_:withinFolder:)

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testResolvePath_pathThatDoesNotExistYet_resolvesUnderFolder() throws {
        let folder = try makeFolder()

        let resolved = CodePushDiffManifest.resolvePath("assets/new.png", withinFolder: folder.path)

        // The folder itself is compared canonically: on the simulator the
        // temporary directory is reached through a symlinked prefix.
        XCTAssertEqual(resolved, folder.resolvingSymlinksInPath().appendingPathComponent("assets/new.png").path)
    }

    func testResolvePath_traversalAndAbsolutePaths_areRejected() throws {
        let folder = try makeFolder()

        XCTAssertNil(CodePushDiffManifest.resolvePath("../escaped.txt", withinFolder: folder.path))
        XCTAssertNil(CodePushDiffManifest.resolvePath("assets/../../escaped.txt", withinFolder: folder.path))
        XCTAssertNil(CodePushDiffManifest.resolvePath("/etc/passwd", withinFolder: folder.path))
        XCTAssertNil(CodePushDiffManifest.resolvePath("", withinFolder: folder.path))
    }

    // An update zip can contain symlink entries, and they are extracted before
    // anything verifies the update's contents.
    func testResolvePath_pathThroughSymlinkOutOfFolder_isRejected() throws {
        let folder = try makeFolder()
        let outsideFolder = try makeFolder()
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("escape"),
            withDestinationURL: outsideFolder)

        XCTAssertNil(CodePushDiffManifest.resolvePath("escape/evil.txt", withinFolder: folder.path))
    }

    func testResolvePath_danglingSymlinkLeaf_isRejected() throws {
        let folder = try makeFolder()
        let outsideFolder = try makeFolder()
        // The link target does not exist, so the link itself is all that can be
        // resolved - and writing to it would still land outside the folder.
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("evil.txt"),
            withDestinationURL: outsideFolder.appendingPathComponent("evil.txt"))

        XCTAssertNil(CodePushDiffManifest.resolvePath("evil.txt", withinFolder: folder.path))
    }

    // A JSON string can hold a NUL, which no file system path can represent.
    func testResolvePath_pathThatIsNotRepresentable_isRejected() throws {
        let folder = try makeFolder()

        XCTAssertNil(CodePushDiffManifest.resolvePath("a\0b", withinFolder: folder.path))
        XCTAssertNil(CodePushDiffManifest.resolvePath(String(repeating: "a", count: 8192), withinFolder: folder.path))
    }

    func testResolvePath_missingFolder_isRejected() {
        let missingFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        XCTAssertNil(CodePushDiffManifest.resolvePath("main.jsbundle", withinFolder: missingFolder.path))
    }
}
