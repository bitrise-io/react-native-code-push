"use strict";

import crypto = require("crypto");
import fs = require("fs");
import mkdirp = require("mkdirp");
import path = require("path");

import { Platform, ProjectManager, ServerUtil, setupUpdateScenario, TestConfig, TestUtil } from "code-push-plugin-testing-framework";

const CODEPUSH_METADATA_FILE_NAME = ".codepushrelease";

function isHashIgnored(relativePath: string): boolean {
    return relativePath.startsWith("__MACOSX/")
        || relativePath === ".DS_Store"
        || relativePath.endsWith("/.DS_Store")
        || relativePath === CODEPUSH_METADATA_FILE_NAME
        || relativePath.endsWith(`/${CODEPUSH_METADATA_FILE_NAME}`);
}

/**
 * Computes the same content hash that the native SDKs compute over an installed update folder, so the mock server
 * can hand back a package_hash that will actually match what the client expects.
 */
export function computeUpdateContentsHash(folderPath: string): string {
    const manifest: string[] = [];

    const walk = (currentPath: string, relativePrefix: string) => {
        for (const entryName of fs.readdirSync(currentPath)) {
            const entryPath = path.join(currentPath, entryName);
            const relativePath = relativePrefix ? `${relativePrefix}/${entryName}` : entryName;

            if (isHashIgnored(relativePath)) {
                continue;
            }

            if (fs.statSync(entryPath).isDirectory()) {
                walk(entryPath, relativePath);
            } else {
                const fileHash = crypto.createHash("sha256").update(fs.readFileSync(entryPath)).digest("hex");
                manifest.push(`${relativePath}:${fileHash}`);
            }
        }
    };

    walk(folderPath, "");
    manifest.sort();

    return crypto.createHash("sha256").update(JSON.stringify(manifest)).digest("hex");
}

const codeSigningPrivateKey = fs.readFileSync(path.join(__dirname, "../test/fixtures/codesigning/test-private-key.pem"), "utf8");
export const codeSigningPublicKey = fs.readFileSync(path.join(__dirname, "../test/fixtures/codesigning/test-public-key.pem"), "utf8").trim();

function base64UrlEncode(input: Buffer): string {
    return input.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Builds the RS256-signed ".codepushrelease" JWT that the native SDKs look for inside an update
 * archive's "CodePush/" folder.
 */
function signUpdateContentsHash(contentHash: string): string {
    const header = base64UrlEncode(Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })));
    const payload = base64UrlEncode(Buffer.from(JSON.stringify({ contentHash })));
    const signature = base64UrlEncode(crypto.sign("RSA-SHA256", Buffer.from(`${header}.${payload}`), codeSigningPrivateKey));
    return `${header}.${payload}.${signature}`;
}

/**
 * Code-signs the update contents with the test key pair and records the real hash, so the mock
 * server hands back a package_hash that matches what the client's data-integrity check computes.
 */
export function signAndRecordUpdateArchive(bundleFolder: string, isDiff: boolean): void {
    // TODO(RA-4875): Diff updates clear it instead, since they are poorly implemented in the entire test harness.
    // It's going to be a bigger refactor, so for now we just skip signing/hashing to avoid using a stale value in diff tests.
    if (isDiff) {
        ServerUtil.setKnownPackageHash(undefined);
        return;
    }

    const contentHash = computeUpdateContentsHash(bundleFolder);
    const signatureFolder = path.join(bundleFolder, "CodePush");
    mkdirp.sync(signatureFolder);
    fs.writeFileSync(path.join(signatureFolder, CODEPUSH_METADATA_FILE_NAME), signUpdateContentsHash(contentHash));
    ServerUtil.setKnownPackageHash(contentHash);
}

export async function setupTamperedSignatureUpdateScenario(projectManager: ProjectManager, targetPlatform: Platform.IPlatform, scenarioJsPath: string, version: string): Promise<string> {
    const updatePath = await setupUpdateScenario(projectManager, targetPlatform, scenarioJsPath, version);

    const bundleFolder = path.join(TestConfig.updatesDirectory, TestConfig.TestAppName, "CodePush/");
    const tamperedHash = "0".repeat(64);
    fs.writeFileSync(path.join(bundleFolder, "CodePush", CODEPUSH_METADATA_FILE_NAME), signUpdateContentsHash(tamperedHash));

    return await TestUtil.archiveFolder(bundleFolder, "", updatePath, false);
}
