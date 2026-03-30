package com.example.app

import com.example.app.config.AppProperties
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import io.flipt.client.FliptClient
import io.flipt.client.models.AuthenticationLease
import io.flipt.client.models.ErrorStrategy
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.DisposableBean
import org.springframework.stereotype.Component
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import java.time.Instant

@Component
class FliptClientProvider(
    private val props: AppProperties
) : DisposableBean {

    private val log = LoggerFactory.getLogger(FliptClientProvider::class.java)
    private val httpClient = HttpClient.newHttpClient()
    private val objectMapper = jacksonObjectMapper()

    final val client: FliptClient

    init {
        log.info("╔══════════════════════════════════════════════════════════════╗")
        log.info("║  Flipt Client SDK — Auth Lease (token refresh via SDK)      ║")
        log.info("║  updateInterval={}s, identityServer={}                      ║", props.updateIntervalSeconds, props.identityServerUrl)
        log.info("╚══════════════════════════════════════════════════════════════╝")

        client = FliptClient.builder()
            .url(props.url)
            .authenticationProvider { fetchAuthLease() }
            .updateInterval(Duration.ofSeconds(props.updateIntervalSeconds.toLong()))
            .errorStrategy(ErrorStrategy.FAIL)
            .build()
    }

    private fun fetchAuthLease(): AuthenticationLease {
        log.info("  [auth-lease] Fetching JWT from identity server: {}", props.identityServerUrl)
        val request = HttpRequest.newBuilder()
            .uri(URI.create("${props.identityServerUrl}/token"))
            .GET()
            .build()
        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())
        val body: Map<String, String> = objectMapper.readValue(response.body())

        val token = body["token"] ?: throw IllegalStateException("No token in identity server response")
        val expiresAt = Instant.parse(body["expires_at"] ?: throw IllegalStateException("No expires_at in response"))

        log.info("  [auth-lease] Got JWT, expires at {} (in {}s)", expiresAt, Duration.between(Instant.now(), expiresAt).seconds)

        return AuthenticationLease.expiring(expiresAt)
            .jwt(token)
            .build()
    }

    override fun destroy() {
        log.info("Shutting down FliptClientProvider")
        client.close()
    }
}
