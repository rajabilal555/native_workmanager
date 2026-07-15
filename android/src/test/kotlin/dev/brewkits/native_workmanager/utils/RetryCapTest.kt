package dev.brewkits.native_workmanager.utils

import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RetryCapTest {

    @Test
    fun `failure shouldRetry false is unchanged`() {
        val result = WorkerResult.Failure("nope", shouldRetry = false)
        val applied = RetryCap.apply(result, runAttemptCount = 0, maxRetries = 3)
        assertTrue(applied is WorkerResult.Failure)
        assertFalse((applied as WorkerResult.Failure).shouldRetry)
    }

    @Test
    fun `failure shouldRetry true retries until maxRetries exhausted`() {
        val fail = WorkerResult.Failure("temp", shouldRetry = true)

        val attempt0 = RetryCap.apply(fail, runAttemptCount = 0, maxRetries = 3) as WorkerResult.Failure
        assertTrue(attempt0.shouldRetry)

        val attempt2 = RetryCap.apply(fail, runAttemptCount = 2, maxRetries = 3) as WorkerResult.Failure
        assertTrue(attempt2.shouldRetry)

        val attempt3 = RetryCap.apply(fail, runAttemptCount = 3, maxRetries = 3) as WorkerResult.Failure
        assertFalse(attempt3.shouldRetry)
    }

    @Test
    fun `maxRetries zero never retries`() {
        val fail = WorkerResult.Failure("temp", shouldRetry = true)
        val applied = RetryCap.apply(fail, runAttemptCount = 0, maxRetries = 0) as WorkerResult.Failure
        assertFalse(applied.shouldRetry)
    }

    @Test
    fun `Retry without attemptCap gets total-attempt cap injected`() {
        val retry = WorkerResult.Retry("later", delayMs = null, attemptCap = null)
        val applied = RetryCap.apply(retry, runAttemptCount = 0, maxRetries = 3) as WorkerResult.Retry
        assertEquals(4, applied.attemptCap) // 1 initial + 3 retries
    }

    @Test
    fun `Retry with explicit attemptCap is preserved`() {
        val retry = WorkerResult.Retry("later", delayMs = null, attemptCap = 5)
        val applied = RetryCap.apply(retry, runAttemptCount = 0, maxRetries = 1) as WorkerResult.Retry
        assertEquals(5, applied.attemptCap)
    }

    @Test
    fun `shouldRetryNow matches Exhausted semantics`() {
        assertTrue(RetryCap.shouldRetryNow(0, 3))
        assertTrue(RetryCap.shouldRetryNow(2, 3))
        assertFalse(RetryCap.shouldRetryNow(3, 3))
        assertFalse(RetryCap.shouldRetryNow(0, 0))
    }
}
