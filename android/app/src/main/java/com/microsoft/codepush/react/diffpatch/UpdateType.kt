package com.microsoft.codepush.react.diffpatch

// Values of the update_type field of the download and deploy status reports. Must be in sync with the server-side impl.
object UpdateType {
    const val FULL = "full"
    const val FILE_LEVEL_DIFF = "file_level_diff"
    const val BINARY_DIFF = "binary_diff"
}
