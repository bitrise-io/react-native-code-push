@file:JvmName("Sha256")
package com.microsoft.codepush.react.diffpatch

import java.io.File
import java.io.InputStream
import java.math.BigInteger
import java.security.DigestInputStream
import java.security.MessageDigest

fun sha256Hex(file: File): String = file.inputStream().use { sha256Hex(it) }

fun sha256Hex(inputStream: InputStream): String {
    val messageDigest = MessageDigest.getInstance("SHA-256")
    DigestInputStream(inputStream, messageDigest).use { digestInputStream ->
        val buffer = ByteArray(1024 * 8)
        while (digestInputStream.read(buffer) != -1) {
            // Drain the stream; DigestInputStream updates the digest as a side effect.
        }
    }
    return String.format("%064x", BigInteger(1, messageDigest.digest()))
}
