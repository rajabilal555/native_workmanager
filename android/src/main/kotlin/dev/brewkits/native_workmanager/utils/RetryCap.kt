package dev.brewkits.native_workmanager.utils

import androidx.work.Data
import androidx.work.ListenableWorker
import dev.brewkits.kmpworkmanager.background.domain.Constraints
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult

/**
 * Enforces [Constraints.maxRetries] on Android.
 *
 * WorkManager has no built-in max-retry count: [ListenableWorker.Result.retry]
 * reschedules forever. KMP [WorkerResult.Failure.shouldRetry] maps to that
 * unbounded path. This helper caps attempts to match Dart / iOS semantics:
 * `maxRetries = N` → up to `N + 1` total runs (initial + N retries).
 */
object RetryCap {
    const val KEY_MAX_RETRIES = "maxRetries"
    const val DEFAULT_MAX_RETRIES = 3

    fun maxRetriesFrom(constraints: Constraints): Int =
        constraints.extras[KEY_MAX_RETRIES]?.toIntOrNull()?.coerceAtLeast(0)
            ?: DEFAULT_MAX_RETRIES

    fun Data.Builder.putMaxRetries(constraints: Constraints): Data.Builder =
        putInt(KEY_MAX_RETRIES, maxRetriesFrom(constraints))

    fun Data.Builder.putMaxRetries(maxRetries: Int): Data.Builder =
        putInt(KEY_MAX_RETRIES, maxRetries.coerceAtLeast(0))

    /**
     * @param runAttemptCount WorkManager's 0-based attempt index
     *   (`ListenableWorker.runAttemptCount`).
     */
    fun apply(
        result: WorkerResult,
        runAttemptCount: Int,
        maxRetries: Int,
    ): WorkerResult {
        val capped = maxRetries.coerceAtLeast(0)
        return when (result) {
            is WorkerResult.Failure -> {
                if (!result.shouldRetry) result
                else if (capped == 0 || runAttemptCount >= capped) {
                    WorkerResult.Failure(result.message, shouldRetry = false)
                } else {
                    result
                }
            }
            is WorkerResult.Retry -> {
                if (result.attemptCap != null) result
                else if (capped == 0) {
                    WorkerResult.Failure(result.reason, shouldRetry = false)
                } else {
                    // attemptCap = total runs; must be >= 2 per KMP Retry validation
                    WorkerResult.Retry(
                        reason = result.reason,
                        delayMs = result.delayMs,
                        attemptCap = maxOf(2, capped + 1),
                    )
                }
            }
            else -> result
        }
    }

    fun shouldRetryNow(runAttemptCount: Int, maxRetries: Int): Boolean {
        val capped = maxRetries.coerceAtLeast(0)
        return capped > 0 && runAttemptCount < capped
    }
}
