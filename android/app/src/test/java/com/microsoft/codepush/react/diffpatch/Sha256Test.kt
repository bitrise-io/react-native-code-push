package com.microsoft.codepush.react.diffpatch

import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class Sha256Test {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun sha256Hex_emptyFile_matchesKnownHash() {
        // Given
        val file = tempFolder.newFile("empty.dat")

        // When
        val hash = sha256Hex(file)

        // Then
        // SHA-256 of the empty byte sequence, a widely published constant.
        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hash)
    }

    @Test
    fun sha256Hex_knownBytes_matchesKnownHash() {
        // Given
        val file = tempFolder.newFile("abc.dat").apply { writeBytes("abc".toByteArray()) }

        // When
        val hash = sha256Hex(file)

        // Then
        // SHA-256("abc"), a widely published constant.
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash)
    }

    @Test
    fun sha256Hex_isZeroPaddedToSixtyFourLowercaseHexChars() {
        // Given
        val file = tempFolder.newFile("small.dat").apply { writeBytes(byteArrayOf(0)) }

        // When
        val hash = sha256Hex(file)

        // Then
        assertEquals(64, hash.length)
        assertEquals(hash.lowercase(), hash)
    }

    @Test
    fun sha256Hex_fileAndInputStreamOverloads_agree() {
        // Given
        val file = tempFolder.newFile("agree.dat").apply { writeBytes("some content".toByteArray()) }

        // When
        val fromFile = sha256Hex(file)
        val fromStream = file.inputStream().use { sha256Hex(it) }

        // Then
        assertEquals(fromFile, fromStream)
    }
}
