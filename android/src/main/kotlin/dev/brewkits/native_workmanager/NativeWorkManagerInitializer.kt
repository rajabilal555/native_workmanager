package dev.brewkits.native_workmanager

import android.content.Context
import android.content.pm.PackageManager
import androidx.startup.Initializer
import dev.brewkits.kmpworkmanager.KmpWorkManager
import dev.brewkits.kmpworkmanager.KmpWorkManagerConfig
import dev.brewkits.native_workmanager.engine.FlutterEngineManager

/**
 * androidx.startup Initializer for native_workmanager.
 *
 * Runs automatically before [android.app.Application.onCreate] so that WorkManager is
 * fully configured before any pending background task is dispatched after a process kill.
 *
 * **What it does:**
 * 1. Reads the [callbackHandle][FlutterEngineManager.setCallbackHandle] persisted by
 *    [NativeWorkmanagerPlugin] during the last Dart-side `NativeWorkManager.initialize()` call.
 * 2. Re-arms [FlutterEngineManager] with that handle so [DartCallbackWorkerWrapper] can
 *    boot the headless Dart isolate on first post-kill task execution.
 * 3. Calls [KmpWorkManager.initialize] with [SimpleAndroidWorkerFactory] so all built-in
 *    workers are available to WorkManager immediately.
 *
 * **Zero-config:** No `AndroidManifest.xml` changes or custom `Application` class required.
 * The plugin's own manifest merges this provider declaration automatically.
 *
 * **Opt-out:** If your app manages WorkManager initialization via a custom `Application`
 * that implements `Configuration.Provider`, add this to your `<application>` block:
 * ```xml
 * <meta-data
 *     android:name="native_workmanager.auto_init"
 *     android:value="false" />
 * ```
 * Then follow the manual setup guide in `doc/ANDROID_SETUP.md`.
 *
 * **Custom workers:** [SimpleAndroidWorkerFactory.registerWorker] is safe to call at any
 * time, even after this Initializer runs. Workers registered before the first task fires
 * will be available for that task.
 */
class NativeWorkManagerInitializer : Initializer<Unit> {

    override fun create(context: Context) {
        if (!isAutoInitEnabled(context)) {
            NativeLogger.d("NativeWorkManagerInitializer: auto_init disabled — skipping")
            return
        }

        // Already initialized by a previous onAttachedToEngine call (e.g. hot restart).
        if (NativeWorkmanagerPlugin.isSchedulerInitialized) {
            NativeLogger.d("NativeWorkManagerInitializer: scheduler already initialized — skipping")
            return
        }

        // Restore callbackHandle persisted by the Dart-side NativeWorkManager.initialize().
        // On the very first app launch this will be -1 (no DartWorker ever registered).
        val prefs = context.getSharedPreferences(
            NativeWorkmanagerPlugin.SHARED_PREFS_NAME, Context.MODE_PRIVATE
        )
        val handle = prefs.getLong(NativeWorkmanagerPlugin.CALLBACK_HANDLE_KEY, -1L)
        if (handle != -1L) {
            FlutterEngineManager.setCallbackHandle(handle)
            NativeLogger.d("NativeWorkManagerInitializer: callbackHandle restored ($handle)")
        }

        val registerPlugins = prefs.getBoolean(NativeWorkmanagerPlugin.REGISTER_PLUGINS_KEY, false)
        FlutterEngineManager.registerPlugins = registerPlugins

        // Initialize the KMP WorkManager engine. Mirrors NativeWorkmanagerPlugin.initializeScheduler().
        try {
            val workerFactory = SimpleAndroidWorkerFactory(context)
            KmpWorkManager.initialize(context, workerFactory, KmpWorkManagerConfig())
            NativeWorkmanagerPlugin.isSchedulerInitialized = true
            NativeLogger.d("NativeWorkManagerInitializer: KmpWorkManager initialized ✅")
        } catch (e: Exception) {
            // Non-fatal: plugin will retry in onAttachedToEngine.
            NativeLogger.e("NativeWorkManagerInitializer: init failed (will retry on engine attach)", e)
        }
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()

    private fun isAutoInitEnabled(context: Context): Boolean {
        return try {
            val ai = context.packageManager.getApplicationInfo(
                context.packageName, PackageManager.GET_META_DATA
            )
            ai.metaData?.getBoolean("native_workmanager.auto_init", true) ?: true
        } catch (e: Exception) {
            true // default: enabled
        }
    }
}
