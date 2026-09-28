package com.microsoft.codepush.react

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class FileUtilsTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun copyDirectoryContents_copiesNestedFilesAndSubdirectories() {
        // Given
        val sourceDir = tempFolder.newFolder("source")
        File(sourceDir, "root.txt").writeText("root contents")
        val nestedDir = File(sourceDir, "nested").apply { mkdir() }
        File(nestedDir, "child.txt").writeText("child contents")

        val destinationDir = File(tempFolder.root, "destination")

        // When
        FileUtils.copyDirectoryContents(sourceDir.absolutePath, destinationDir.absolutePath)

        // Then
        assertEquals("root contents", File(destinationDir, "root.txt").readText())
        val copiedNestedFile = File(destinationDir, "nested/child.txt")
        assertTrue(copiedNestedFile.exists())
        assertEquals("child contents", copiedNestedFile.readText())
    }

    @Test
    fun copyDirectoryContents_withExcludedEntry_skipsItOnlyAtTopLevel() {
        // Given
        val sourceDir = tempFolder.newFolder("source")
        File(sourceDir, "root.txt").writeText("root contents")
        File(sourceDir, "excluded").mkdir()
        File(sourceDir, "excluded/skipped.txt").writeText("skipped contents")
        File(sourceDir, "nested/excluded").mkdirs()
        File(sourceDir, "nested/excluded/kept.txt").writeText("kept contents")

        val destinationDir = File(tempFolder.root, "destination")

        // When
        FileUtils.copyDirectoryContents(sourceDir.absolutePath, destinationDir.absolutePath, "excluded")

        // Then
        assertEquals("root contents", File(destinationDir, "root.txt").readText())
        assertFalse(File(destinationDir, "excluded").exists())
        assertEquals("kept contents", File(destinationDir, "nested/excluded/kept.txt").readText())
    }
}
