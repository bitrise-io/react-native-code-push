@file:JvmName("NetworkUtils")

package com.microsoft.codepush.react

import java.io.InputStream

fun readStreamToString(inputStream: InputStream?): String {
    return inputStream?.bufferedReader()?.use { it.readText() } ?: ""
}
