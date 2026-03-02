package com.example.app.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "flipt")
data class AppProperties(
    val url: String = "http://localhost:8080",
    val identityServerUrl: String = "http://localhost:9090",
    val updateIntervalSeconds: Int = 10
)
