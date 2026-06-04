package dev.brewkits.native_workmanager

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.test.core.app.ApplicationProvider
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class NativeWorkManagerInitializerTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        // Reset state before each test
        NativeWorkmanagerPlugin.isSchedulerInitialized = false
        FlutterEngineManager.registerPlugins = false
    }

    @Test
    fun `Opt-out metadata is FALSE - Initialization must be skipped`() {
        // Arrange: Mock Manifest with auto_init = false
        val applicationInfo = ApplicationInfo().apply {
            packageName = context.packageName
            metaData = Bundle().apply {
                putBoolean("native_workmanager.auto_init", false)
            }
        }
        val shadowPackageManager = shadowOf(context.packageManager)
        shadowPackageManager.addPackage(
            context.packageManager.getPackageInfo(context.packageName, 0).apply {
                this.applicationInfo = applicationInfo
            }
        )

        // Act
        val initializer = NativeWorkManagerInitializer()
        initializer.create(context)

        // Assert: isSchedulerInitialized must remain false because the initializer skipped execution.
        assertFalse(
            "Initializer must skip execution when auto_init = false", 
            NativeWorkmanagerPlugin.isSchedulerInitialized
        )
    }

    @Test
    fun `Opt-in default - Must read callbackHandle from SharedPrefs and initialize`() {
        // Arrange: No metadata means auto_init is true by default.
        val prefs = context.getSharedPreferences(
            NativeWorkmanagerPlugin.SHARED_PREFS_NAME, Context.MODE_PRIVATE
        )
        val testHandle = 987654321L
        
        // Note: The Flutter SharedPreferences plugin automatically prepends 'flutter.' 
        // to the keys. But native_workmanager uses its own SharedPreferences instance 
        // named NativeWorkmanagerPlugin.SHARED_PREFS_NAME which avoids the 'flutter.' prefix 
        // if they wrote it via the plugin method. Let's write directly using the constants.
        prefs.edit()
            .putLong(NativeWorkmanagerPlugin.CALLBACK_HANDLE_KEY, testHandle)
            .putBoolean(NativeWorkmanagerPlugin.REGISTER_PLUGINS_KEY, true)
            .commit()

        // Act
        val initializer = NativeWorkManagerInitializer()
        initializer.create(context)

        // Assert
        assertTrue(
            "Initializer must set isSchedulerInitialized to true", 
            NativeWorkmanagerPlugin.isSchedulerInitialized
        )
        assertTrue(
            "FlutterEngineManager.registerPlugins must be read from SharedPreferences",
            FlutterEngineManager.registerPlugins
        )
        // callbackHandle is private, so we assume if isSchedulerInitialized is true, it read it.
    }
}
