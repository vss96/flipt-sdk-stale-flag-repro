package com.example.identity

import com.nimbusds.jose.JWSAlgorithm
import com.nimbusds.jose.JWSHeader
import com.nimbusds.jose.crypto.RSASSASigner
import com.nimbusds.jwt.JWTClaimsSet
import com.nimbusds.jwt.SignedJWT
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.nio.file.Files
import java.nio.file.Path
import java.security.KeyFactory
import java.security.interfaces.RSAPrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.util.*

@RestController
class TokenController(
    @param:Value("\${identity.private-key-path}") private val privateKeyPath: String
) {
    private val log = LoggerFactory.getLogger(TokenController::class.java)

    @GetMapping("/token")
    fun getToken(): Map<String, String> {
        val privateKey = loadPrivateKey()
        val now = Date()
        val expiry = Date(now.time + 86_400_000) // 86400 seconds (24 hours)

        val claims = JWTClaimsSet.Builder()
            .issuer("flipt-identity-server")
            .subject("flipt-client-app")
            .expirationTime(expiry)
            .issueTime(now)
            .build()

        val header = JWSHeader.Builder(JWSAlgorithm.RS256).build()
        val signedJWT = SignedJWT(header, claims)
        signedJWT.sign(RSASSASigner(privateKey))

        val token = signedJWT.serialize()
        log.info("Issued JWT: sub={}, exp={}", claims.subject, claims.expirationTime)
        return mapOf("token" to token)
    }

    private fun loadPrivateKey(): RSAPrivateKey {
        val pem = Files.readString(Path.of(privateKeyPath))
        val base64 = pem
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\\s".toRegex(), "")
        val decoded = Base64.getDecoder().decode(base64)
        val keySpec = PKCS8EncodedKeySpec(decoded)
        return KeyFactory.getInstance("RSA").generatePrivate(keySpec) as RSAPrivateKey
    }
}
