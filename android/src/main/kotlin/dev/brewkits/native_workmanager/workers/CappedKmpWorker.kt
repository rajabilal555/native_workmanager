package dev.brewkits.native_workmanager.workers

import android.content.Context
import androidx.work.Data
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.KmpWorkManagerKoin
import dev.brewkits.kmpworkmanager.background.data.BaseKmpWorker
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import dev.brewkits.kmpworkmanager.background.domain.ProgressListener
import dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment
import dev.brewkits.kmpworkmanager.background.domain.WorkerProgress
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.utils.RetryCap

/**
 * Drop-in replacement for [dev.brewkits.kmpworkmanager.background.data.KmpWorker]
 * that honors [RetryCap.KEY_MAX_RETRIES] from WorkRequest input data.
 *
 * Upstream [dev.brewkits.kmpworkmanager.background.data.KmpWorker] is final and maps
 * [WorkerResult.Failure.shouldRetry] to unbounded [androidx.work.ListenableWorker.Result.retry].
 */
class CappedKmpWorker(
    appContext: Context,
    workerParams: WorkerParameters,
    workerFactory: AndroidWorkerFactory,
) : BaseKmpWorker(appContext, workerParams, workerFactory) {

    constructor(appContext: Context, workerParams: WorkerParameters) : this(
        appContext,
        workerParams,
        KmpWorkManagerKoin.getKoin().get<AndroidWorkerFactory>(),
    )

    override fun getWorkerLogTag(): String = "CappedKmpWorker"

    override suspend fun performWork(
        workerClassName: String,
        inputJson: String?,
    ): WorkerResult {
        val worker = kmpWorkerFactory.createWorker(workerClassName)
            ?: return WorkerResult.Failure(
                "Worker not found: $workerClassName",
                shouldRetry = false,
            )

        val env = WorkerEnvironment(
            object : ProgressListener {
                override fun onProgressUpdate(progress: WorkerProgress) {
                    setProgressAsync(
                        Data.Builder().putInt("progress", progress.progress).build()
                    )
                }
            },
            { isStopped },
        )

        return RetryCap.apply(
            result = worker.doWork(inputJson, env),
            runAttemptCount = runAttemptCount,
            maxRetries = inputData.getInt(
                RetryCap.KEY_MAX_RETRIES,
                RetryCap.DEFAULT_MAX_RETRIES,
            ),
        )
    }
}

/**
 * Drop-in replacement for [KmpHeavyWorker] with the same retry cap.
 */
class CappedKmpHeavyWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : KmpHeavyWorker(appContext, workerParams) {

    override suspend fun performWork(
        workerClassName: String,
        inputJson: String?,
    ): WorkerResult {
        return RetryCap.apply(
            result = super.performWork(workerClassName, inputJson),
            runAttemptCount = runAttemptCount,
            maxRetries = inputData.getInt(
                RetryCap.KEY_MAX_RETRIES,
                RetryCap.DEFAULT_MAX_RETRIES,
            ),
        )
    }
}
