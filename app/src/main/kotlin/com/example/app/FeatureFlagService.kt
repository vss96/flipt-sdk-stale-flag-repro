package com.example.app

import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.Duration
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger

/**
 * Consumer that periodically evaluates feature flags via FliptClientProvider.
 * Mirrors production pattern: separate service from client lifecycle management.
 */
@Component
class FeatureFlagService(
    private val provider: FliptClientProvider
) {

    private val log = LoggerFactory.getLogger(FeatureFlagService::class.java)
    private val evaluationCount = AtomicInteger(0)

    private var lastKnownFlagValue: Boolean? = null
    private var lastValueChangeDetected: Instant? = null

    @Scheduled(fixedRate = 3_000, initialDelay = 1_000)
    fun evaluateFlag() {
        val evalNum = evaluationCount.incrementAndGet()
        val now = Instant.now()

        try {
            val client = provider.getClient()
            val result = client.evaluateBoolean("test-flag", "entity-1", mapOf<String, String>())
            val currentValue = result.isEnabled

            val listFlagValue = try {
                client.listFlags()?.find { it.key == "test-flag" }?.isEnabled
            } catch (e: Exception) {
                null
            }

            if (lastKnownFlagValue != null && lastKnownFlagValue != currentValue) {
                val lastChange = lastValueChangeDetected
                lastValueChangeDetected = now
                log.info("  ┌─────────────────────────────────────────────────────────┐")
                log.info("  │ *** FLAG VALUE CHANGED: {} → {} ***", lastKnownFlagValue, currentValue)
                log.info("  │ Detected at: {}", now)
                log.info("  │ Evaluation #{}", evalNum)
                log.info("  │ listFlags(test-flag)={}", listFlagValue)
                if (lastChange != null) {
                    log.info("  │ Time since last change: {}s", Duration.between(lastChange, now).seconds)
                }
                log.info("  └─────────────────────────────────────────────────────────┘")
            } else {
                log.info(
                    "  [eval #{}] test-flag={}, listFlags={}, time={}",
                    evalNum, currentValue, listFlagValue, now
                )
            }

            lastKnownFlagValue = currentValue
        } catch (e: Exception) {
            log.error("  [eval #{}] EVALUATION FAILED: {}", evalNum, e.message, e)
        }
    }
}
