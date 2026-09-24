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

    func testManifest_patchedFilesEntryWrongTypedField_throws() {
        let json: [AnyHashable: Any] = [
            "version": 2,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": 42,
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json)) { error in
            // A present-but-wrong-typed field is a different defect than an
            // absent one, and the message must say so rather than claiming
            // the field is missing.
            XCTAssertTrue(error.localizedDescription.contains("must be a string"), error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.contains("missing required field"), error.localizedDescription)
        }
    }

    // A version that is not an integer must not fall back to 1 or get
    // truncated to a neighboring version: either would skip every patch of a
    // version 2 manifest and install the old bytes.
    func testManifest_invalidVersionValues_throw() {
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": "2"]))
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": 2.7]))
        XCTAssertThrowsError(try CodePushDiffManifest(json: ["version": true]))

        let jsonWithPatchedFiles: [AnyHashable: Any] = [
            "version": 2.7,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "__hcp_patches/main.jsbundle.bsdiff",
                ]
            ],
        ]
        XCTAssertThrowsError(try CodePushDiffManifest(json: jsonWithPatchedFiles))
    }

    func testManifest_patchedFilesEntryPatchOutsideReservedPrefix_throws() {
        let json: [AnyHashable: Any] = [
            "version": 2,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json)) { error in
            XCTAssertTrue(error.localizedDescription.contains("__hcp_patches/"), error.localizedDescription)
        }
    }

    func testManifest_patchedFilesEntryPatchWithPrefixButNoSlash_throws() {
        let json: [AnyHashable: Any] = [
            "version": 2,
            "patchedFiles": [
                "main.jsbundle": [
                    "algo": "bsdiff",
                    "baseHash": "aaaa",
                    "targetHash": "bbbb",
                    "patch": "__hcp_patchesX/main.jsbundle.bsdiff",
                ]
            ],
        ]

        XCTAssertThrowsError(try CodePushDiffManifest(json: json)) { error in
            XCTAssertTrue(error.localizedDescription.contains("__hcp_patches/"), error.localizedDescription)
        }
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

    private func assertRejected(_ path: String, withinFolder folder: String, messageContains needle: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try CodePushDiffManifest.resolvePath(path, withinFolder: folder), file: file, line: line) { error in
            let message = (error as NSError).localizedDescription
            XCTAssertTrue(message.contains(needle), message, file: file, line: line)
        }
    }

    func testResolvePath_pathThatDoesNotExistYet_resolvesUnderFolder() throws {
        let folder = try makeFolder()

        let resolved = try CodePushDiffManifest.resolvePath("assets/new.png", withinFolder: folder.path)

        // The folder itself is compared canonically: on the simulator the
        // temporary directory is reached through a symlinked prefix.
        XCTAssertEqual(resolved, folder.resolvingSymlinksInPath().appendingPathComponent("assets/new.png").path)
    }

    // "." components in the not-yet-existing part of the path must not survive
    // into the result verbatim, or callers comparing/logging the resolved path
    // would see a subtly different string than a fully normalized one.
    func testResolvePath_dotComponentsInMissingSuffix_areNormalizedAway() throws {
        let folder = try makeFolder()

        let resolved = try CodePushDiffManifest.resolvePath("assets/./sub/./new.png", withinFolder: folder.path)

        XCTAssertEqual(resolved, folder.resolvingSymlinksInPath().appendingPathComponent("assets/sub/new.png").path)
    }

    func testResolvePath_traversalAndAbsolutePaths_areRejected() throws {
        let folder = try makeFolder()

        assertRejected("../escaped.txt", withinFolder: folder.path, messageContains: "escapes")
        assertRejected("assets/../../escaped.txt", withinFolder: folder.path, messageContains: "escapes")
        assertRejected("/etc/passwd", withinFolder: folder.path, messageContains: "escapes")
    }

    // An empty relativePath is a malformed manifest entry, not an attempted
    // escape - the message must say so, or whoever reads the log goes looking
    // for an attack that a bad manifest doesn't represent.
    func testResolvePath_emptyPath_isRejectedAsMalformed() throws {
        let folder = try makeFolder()

        assertRejected("", withinFolder: folder.path, messageContains: "empty")
    }

    // An update zip can contain symlink entries, and they are extracted before
    // anything verifies the update's contents.
    func testResolvePath_pathThroughSymlinkOutOfFolder_isRejected() throws {
        let folder = try makeFolder()
        let outsideFolder = try makeFolder()
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("escape"),
            withDestinationURL: outsideFolder)

        assertRejected("escape/evil.txt", withinFolder: folder.path, messageContains: "escapes")
    }

    func testResolvePath_danglingSymlinkLeaf_isRejected() throws {
        let folder = try makeFolder()
        let outsideFolder = try makeFolder()
        // The link target does not exist, so the link itself is all that can be
        // resolved - and writing to it would still land outside the folder.
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("evil.txt"),
            withDestinationURL: outsideFolder.appendingPathComponent("evil.txt"))

        assertRejected("evil.txt", withinFolder: folder.path, messageContains: "escapes")
    }

    // Unlike the leaf case above, the dangling link here is not the last
    // component, which exercises the multi-component branch of
    // canonicalPathAllowingMissingComponents rather than the single-component one.
    func testResolvePath_danglingSymlinkIntermediateComponent_isRejected() throws {
        let folder = try makeFolder()
        let outsideFolder = try makeFolder()
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("ghost"),
            withDestinationURL: outsideFolder.appendingPathComponent("missing"))

        assertRejected("ghost/f.txt", withinFolder: folder.path, messageContains: "escapes")
    }

    // A symlink whose target stays inside the folder must not be rejected -
    // resolvePath only defends against escaping the folder, not against
    // symlinks in general - and the result must be the link's target, not the
    // link itself.
    func testResolvePath_symlinkStayingInsideFolder_isAccepted() throws {
        let folder = try makeFolder()
        let realSubfolder = folder.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: realSubfolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("inner"),
            withDestinationURL: realSubfolder)

        let resolved = try CodePushDiffManifest.resolvePath("inner/f.txt", withinFolder: folder.path)

        XCTAssertEqual(resolved, realSubfolder.resolvingSymlinksInPath().appendingPathComponent("f.txt").path)
    }

    // A JSON string can hold a NUL, which no file system path can represent -
    // and, like the empty-path case above, this is a malformed manifest, not
    // an escape attempt.
    func testResolvePath_pathThatIsNotRepresentable_isRejected() throws {
        let folder = try makeFolder()

        assertRejected("a\0b", withinFolder: folder.path, messageContains: "cannot be represented")
        assertRejected(String(repeating: "a", count: 8192), withinFolder: folder.path, messageContains: "cannot be represented")
    }

    // A missing base folder is an unusable-environment problem, not a
    // manifest attack - conflating the two sends whoever reads the log
    // looking for an attacker instead of a missing directory.
    func testResolvePath_missingFolder_isRejected() {
        let missingFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        assertRejected("main.jsbundle", withinFolder: missingFolder.path, messageContains: "does not exist")
    }

    func testResolvePath_pathResolvingToFolderItself_isRejected() throws {
        let folder = try makeFolder()

        assertRejected(".", withinFolder: folder.path, messageContains: "escapes")
        assertRejected("./", withinFolder: folder.path, messageContains: "escapes")
    }

    func testResolvePath_symlinkResolvingToFolderItself_isRejected() throws {
        let folder = try makeFolder()
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("self"),
            withDestinationURL: folder)

        assertRejected("self", withinFolder: folder.path, messageContains: "escapes")
    }
}
