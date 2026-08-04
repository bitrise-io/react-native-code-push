"use strict";
var archiver = require("archiver");
var child_process = require("child_process");
var fs = require("fs");
var replace = require("replace");
var Q = require("q");
var TestUtil = (function () {
    function TestUtil() {
    }
    //// Command Line Input Functions
    /**
     * Reads a command line option passed to mocha and returns a default if unspecified.
     */
    TestUtil.readMochaCommandLineOption = function (optionName, defaultValue) {
        var optionValue = undefined;
        for (var i = 0; i < process.argv.length; i++) {
            if (process.argv[i] === optionName) {
                if (i + 1 < process.argv.length) {
                    optionValue = process.argv[i + 1];
                }
                break;
            }
        }
        if (!optionValue)
            optionValue = defaultValue;
        return optionValue;
    };
    /**
     * Reads command line options passed to mocha.
     */
    TestUtil.readMochaCommandLineFlag = function (optionName) {
        for (var i = 0; i < process.argv.length; i++) {
            if (process.argv[i] === optionName) {
                return true;
            }
        }
        return false;
    };
    //// Utility Functions
    /**
     * Executes a child process and returns a promise that resolves with its output or rejects with its error.
     */
    TestUtil.getProcessOutput = function (command, options) {
        var deferred = Q.defer();
        options = options || {};
        // set default options
        if (options.maxBuffer === undefined)
            options.maxBuffer = 1024 * 1024 * 500;
        if (options.timeout === undefined)
            options.timeout = 10 * 60 * 1000;
        if (!options.noLogCommand)
            console.log("Running command: " + command);
        var __timingStart = Date.now();
        var __timingLabel = command.length > 80 ? command.slice(0, 80) + "..." : command;
        var execProcess = child_process.exec(command, options, function (error, stdout, stderr) {
            console.log("[TIMING] exec \"" + __timingLabel + "\" took " + (Date.now() - __timingStart) + "ms");
            if (error) {
                // Always surface full output on failure, even if noLogStdOut/noLogStdErr
                // silenced it on the success path above - otherwise failures are undiagnosable.
                console.error("" + error);
                if (stdout)
                    console.error("stdout:\n" + stdout);
                if (stderr)
                    console.error("stderr:\n" + stderr);
                deferred.reject(error);
            }
            else {
                deferred.resolve(stdout.toString());
            }
        });
        if (!options.noLogStdOut)
            execProcess.stdout.pipe(process.stdout);
        if (!options.noLogStdErr)
            execProcess.stderr.pipe(process.stderr);
        execProcess.on('error', function (error) {
            console.error("" + error);
            deferred.reject(error);
        });
        return deferred.promise;
    };
    /**
     * Like getProcessOutput, but additionally logs a [TIMING] line for each "✔ <phase>"
     * progress marker the child process prints to stdout (e.g. the phases printed by
     * `@react-native-community/cli init`), so long opaque commands can be broken down
     * into their constituent phases without changing their behavior.
     */
    TestUtil.getProcessOutputWithPhaseTiming = function (command, options) {
        var deferred = Q.defer();
        options = options || {};
        if (options.timeout === undefined)
            options.timeout = 10 * 60 * 1000;
        if (!options.noLogCommand)
            console.log("Running command: " + command);
        var __timingStart = Date.now();
        var __lastMarker = __timingStart;
        var __label = command.length > 80 ? command.slice(0, 80) + "..." : command;
        var child = child_process.spawn(command, [], { cwd: options.cwd, env: options.env, shell: true });
        var stdoutBuf = "";
        var stderrBuf = "";
        var pendingStdoutLine = "";
        var pendingStderrLine = "";
        function handleLine(line) {
            var trimmed = line.trim();
            if (trimmed.indexOf("✔") === 0) {
                var now = Date.now();
                var phaseName = trimmed.replace(/^✔\s*/, "");
                console.log("[TIMING] phase \"" + phaseName + "\" took " + (now - __lastMarker) + "ms (cumulative " + (now - __timingStart) + "ms)");
                __lastMarker = now;
            }
        }
        child.stdout.on("data", function (chunk) {
            stdoutBuf += chunk;
            pendingStdoutLine += chunk.toString();
            var lines = pendingStdoutLine.split("\n");
            pendingStdoutLine = lines.pop();
            lines.forEach(handleLine);
            if (!options.noLogStdOut)
                process.stdout.write(chunk);
        });
        child.stderr.on("data", function (chunk) {
            stderrBuf += chunk;
            pendingStderrLine += chunk.toString();
            var stderrLines = pendingStderrLine.split("\n");
            pendingStderrLine = stderrLines.pop();
            stderrLines.forEach(handleLine);
            if (!options.noLogStdErr)
                process.stderr.write(chunk);
        });
        var timeoutHandle = setTimeout(function () {
            child.kill();
        }, options.timeout);
        child.on("error", function (error) {
            clearTimeout(timeoutHandle);
            console.error("" + error);
            deferred.reject(error);
        });
        child.on("close", function (code) {
            clearTimeout(timeoutHandle);
            console.log("[TIMING] exec \"" + __label + "\" took " + (Date.now() - __timingStart) + "ms");
            if (code !== 0) {
                var error = new Error(command + " exited with code " + code);
                // Always surface full output on failure, even if noLogStdOut/noLogStdErr
                // silenced it on the success path above - otherwise failures are undiagnosable.
                console.error("" + error);
                if (stdoutBuf)
                    console.error("stdout:\n" + stdoutBuf);
                if (stderrBuf)
                    console.error("stderr:\n" + stderrBuf);
                deferred.reject(error);
            }
            else {
                deferred.resolve(stdoutBuf.toString());
            }
        });
        return deferred.promise;
    };
    /**
     * Returns the name of the plugin that is being tested.
     */
    TestUtil.getPluginName = function () {
        var packageFile = JSON.parse(fs.readFileSync("./package.json", "utf8"));
        return packageFile.name;
    };

    TestUtil.getPluginVersion = function () {
        var packageFile = JSON.parse(fs.readFileSync("./package.json", "utf8"));
        return packageFile.version;
    };
    /**
     * Replaces a regex in a file with a given string.
     */
    TestUtil.replaceString = function (filePath, regex, replacement) {
        console.log("replacing \"" + regex + "\" with \"" + replacement + "\" in " + filePath);
        replace({ regex: regex, replacement: replacement, recursive: false, silent: true, paths: [filePath] });
    };
    /**
     * Copies a file from a given location to another.
     */
    TestUtil.copyFile = function (source, destination, overwrite) {
        var deferred = Q.defer();
        try {
            var errorHandler = function (error) {
                deferred.reject(error);
            };
            if (overwrite && fs.existsSync(destination)) {
                fs.unlinkSync(destination);
            }
            var readStream = fs.createReadStream(source);
            readStream.on("error", errorHandler);
            var writeStream = fs.createWriteStream(destination);
            writeStream.on("error", errorHandler);
            writeStream.on("close", deferred.resolve.bind(undefined, undefined));
            readStream.pipe(writeStream);
        }
        catch (e) {
            deferred.reject(e);
        }
        return deferred.promise;
    };
    /**
     * Archives the contents of sourceFolder and puts it in an archive at archivePath in targetFolder.
     */
    TestUtil.archiveFolder = function (sourceFolder, targetFolder, archivePath, isDiff) {
        var deferred = Q.defer();
        var archive = archiver.create("zip", {});
        console.log("Creating an update archive at: " + archivePath);
        if (fs.existsSync(archivePath)) {
            fs.unlinkSync(archivePath);
        }
        var writeStream = fs.createWriteStream(archivePath);
        writeStream.on("close", function () {
            deferred.resolve(archivePath);
        });
        archive.on("error", function (e) {
            deferred.reject(e);
        });
        if (isDiff) {
            archive.append("{\"deletedFiles\":[]}", { name: "hotcodepush.json" });
        }
        archive.directory(sourceFolder, targetFolder);
        archive.pipe(writeStream);
        archive.finalize();
        return deferred.promise;
    };

    /**
     * Check that boolean environment variable string is 'true.
     */
    TestUtil.resolveBooleanVariables = function (variable) {
        if (variable) {
            return variable.toLowerCase() === 'true';
        }

        return false;
    }
    //// Placeholders
    // Used in the template to represent data that needs to be added by the testing framework at runtime.
    TestUtil.ANDROID_KEY_PLACEHOLDER = "CODE_PUSH_ANDROID_DEPLOYMENT_KEY";
    TestUtil.IOS_KEY_PLACEHOLDER = "CODE_PUSH_IOS_DEPLOYMENT_KEY";
    TestUtil.SERVER_URL_PLACEHOLDER = "CODE_PUSH_SERVER_URL";
    TestUtil.INDEX_JS_PLACEHOLDER = "CODE_PUSH_INDEX_JS_PATH";
    TestUtil.CODE_PUSH_APP_VERSION_PLACEHOLDER = "CODE_PUSH_APP_VERSION";
    TestUtil.CODE_PUSH_TEST_APP_NAME_PLACEHOLDER = "CODE_PUSH_TEST_APP_NAME";
    TestUtil.CODE_PUSH_APP_ID_PLACEHOLDER = "CODE_PUSH_TEST_APPLICATION_ID";
    TestUtil.PLUGIN_VERSION_PLACEHOLDER = "CODE_PUSH_PLUGIN_VERSION";
    return TestUtil;
}());
exports.TestUtil = TestUtil;
