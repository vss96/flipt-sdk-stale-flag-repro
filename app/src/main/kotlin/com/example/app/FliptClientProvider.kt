package com.example.app

import com.example.app.config.AppProperties
import io.flipt.client.FliptClient
import io.flipt.client.models.ClientTokenAuthentication
import io.flipt.client.models.ErrorStrategy
import io.flipt.client.models.TlsConfig
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.DisposableBean
import org.springframework.stereotype.Component
import java.time.Duration
import java.time.Instant

/**
 * Mirrors production FliptClientConfiguration pattern:
 * - Holds a @Volatile FliptClient + token with expiry tracking
 * - getClient() returns existing client if token not expired, otherwise synchronized rebuild
 * - Token expiry set to 24h so client is NOT rebuilt during test
 */
@Component
class FliptClientProvider(
    private val props: AppProperties
) : DisposableBean {

    private val log = LoggerFactory.getLogger(FliptClientProvider::class.java)

    @Volatile
    private var client: FliptClient? = null

    @Volatile
    private var tokenExpiresAt: Instant = Instant.MIN

    private val tokenExpirySeconds = 86400L // 24h — client won't be rebuilt during test

    init {
        log.info("╔══════════════════════════════════════════════════════════════╗")
        log.info("║  Flipt Client SDK — Production Pattern (Provider+Consumer)  ║")
        log.info("║  updateInterval={}s, tokenExpiry={}s                     ║", props.updateIntervalSeconds, tokenExpirySeconds)
        log.info("║  ClientTokenAuthentication + ErrorStrategy.FAIL             ║")
        log.info("╚══════════════════════════════════════════════════════════════╝")
    }

    fun getClient(): FliptClient {
        val existing = client
        if (existing != null && Instant.now().isBefore(tokenExpiresAt)) {
            return existing
        }
        return synchronized(this) {
            // Double-check inside lock
            val current = client
            if (current != null && Instant.now().isBefore(tokenExpiresAt)) {
                return@synchronized current
            }
            log.info("  [provider] Token expired or no client — rebuilding FliptClient")
            current?.close()
            createClient().also {
                client = it
                tokenExpiresAt = Instant.now().plusSeconds(tokenExpirySeconds)
                log.info("  [provider] New client created, token expires at {}", tokenExpiresAt)
            }
        }
    }

    private fun createClient(): FliptClient {
        return FliptClient.builder()
            .url(props.url)
            .authentication(ClientTokenAuthentication("test-token-123"))
            .updateInterval(Duration.ofSeconds(props.updateIntervalSeconds.toLong()))
            .tlsConfig(TlsConfig.builder().caCertFile("/certs/ca.pem").build())
            .errorStrategy(ErrorStrategy.FAIL)
            .build()
    }

    override fun destroy() {
        log.info("Shutting down FliptClientProvider")
        client?.close()
    }
}
