package dev.brewkits.native_workmanager.workers

import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for [SecurityValidator.validateFilePathSafe].
 *
 * v1.2.4 added a blanket "/data" prefix to the blocked list, which rejected every
 * app-private path (path_provider returns paths under /data/data/<pkg> and
 * /data/user/<n>/<pkg>). That broke all file workers (download/upload/compress/
 * image/crypto) on real Android devices. These tests pin the corrected behaviour:
 * the app sandbox under /data is allowed, while genuinely OS-owned directories
 * (including the sensitive sub-dirs of /data) stay blocked.
 */
class SecurityValidatorFilePathTest {

    // --- App-private sandbox paths MUST be allowed (the regression) ---

    @Test
    fun `app code_cache under data data is allowed`() {
        assertTrue(
            SecurityValidator.validateFilePathSafe(
                "/data/data/dev.brewkits.native_workmanager_example/code_cache/out.txt",
            ),
        )
    }

    @Test
    fun `app cache under data user is allowed`() {
        assertTrue(
            SecurityValidator.validateFilePathSafe(
                "/data/user/0/dev.brewkits.native_workmanager_example/cache/download.json",
            ),
        )
    }

    @Test
    fun `app files dir under data data is allowed`() {
        assertTrue(
            SecurityValidator.validateFilePathSafe(
                "/data/data/com.example.app/files/report.pdf",
            ),
        )
    }

    @Test
    fun `external app storage is allowed`() {
        assertTrue(
            SecurityValidator.validateFilePathSafe(
                "/storage/emulated/0/Android/data/com.example.app/files/photo.png",
            ),
        )
    }

    // --- Genuinely OS-owned directories MUST stay blocked ---

    @Test
    fun `data local tmp is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/data/local/tmp/payload.sh"))
    }

    @Test
    fun `data system is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/data/system/packages.xml"))
    }

    @Test
    fun `data misc is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/data/misc/keystore/key"))
    }

    @Test
    fun `proc is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/proc/self/maps"))
    }

    @Test
    fun `sys is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/sys/kernel/debug"))
    }

    @Test
    fun `vendor is blocked`() {
        assertFalse(SecurityValidator.validateFilePathSafe("/vendor/bin/foo"))
    }

    // Note: /etc and /system are also in the blocked list and work correctly on
    // an Android device, but they are NOT unit-tested here because these tests run
    // on the host JVM, where File.canonicalPath resolves them against the host
    // filesystem (on macOS /etc -> /private/etc via symlink, and /system -> /System
    // via the case-insensitive APFS), so the canonical path no longer carries the
    // blocked prefix. The traversal test below still exercises /system blocking via
    // a literal (non-existent) path that canonicalPath leaves untouched.

    // --- Traversal escapes out of the sandbox into system space stay blocked ---

    @Test
    fun `traversal from app dir into system is blocked`() {
        // canonicalPath collapses the ".." segments to "/system/build.prop".
        assertFalse(
            SecurityValidator.validateFilePathSafe(
                "/data/data/com.example.app/../../../system/build.prop",
            ),
        )
    }

    // --- Basic input validation ---

    @Test
    fun `empty path is rejected`() {
        assertFalse(SecurityValidator.validateFilePathSafe(""))
    }

    @Test
    fun `relative path is rejected`() {
        assertFalse(SecurityValidator.validateFilePathSafe("relative/path/file.txt"))
    }
}
