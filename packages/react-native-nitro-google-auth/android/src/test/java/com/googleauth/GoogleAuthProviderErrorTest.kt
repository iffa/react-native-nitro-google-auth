package com.googleauth

import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import com.google.android.gms.common.ConnectionResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class GoogleAuthProviderErrorTest(
    private val status: Int,
    private val expectedCode: String,
) {
    @Test
    fun classifiesProviderFailureAndPreservesNativeDiagnostics() {
        val exception = GetCredentialProviderConfigurationException("No provider found")
        val result = credentialProviderError(exception, status, "26.01.00")

        assertEquals(expectedCode, result.code)
        assertTrue(result.message.isNotBlank())
        assertNotNull(result.android)
        val diagnostics = requireNotNull(result.android)
        assertEquals(status.toDouble(), diagnostics.playServicesStatus, 0.0)
        assertEquals("26.01.00", diagnostics.playServicesVersion)
        assertEquals(exception.javaClass.name, diagnostics.nativeExceptionType)
        assertEquals(exception.message, diagnostics.nativeMessage)
        assertEquals(exception.stackTraceToString(), diagnostics.nativeStackTrace)
    }

    @Test
    fun handlesMissingPackageVersionAndExceptionMessage() {
        val result = credentialProviderError(
            GetCredentialProviderConfigurationException(),
            status,
            null,
        )

        assertEquals(expectedCode, result.code)
        val diagnostics = requireNotNull(result.android)
        assertNull(diagnostics.playServicesVersion)
        assertNull(diagnostics.nativeMessage)
    }

    companion object {
        @JvmStatic
        @Parameterized.Parameters(name = "status {0} returns {1}")
        fun cases(): List<Array<Any>> = listOf(
            arrayOf(ConnectionResult.SERVICE_MISSING, "PLAY_SERVICES_MISSING"),
            arrayOf(ConnectionResult.SERVICE_DISABLED, "PLAY_SERVICES_DISABLED"),
            arrayOf(ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED, "PLAY_SERVICES_UPDATE_REQUIRED"),
            arrayOf(ConnectionResult.SERVICE_UPDATING, "PLAY_SERVICES_UPDATING"),
            arrayOf(ConnectionResult.SERVICE_INVALID, "PLAY_SERVICES_INVALID"),
            arrayOf(ConnectionResult.SUCCESS, "CREDENTIAL_PROVIDER_UNAVAILABLE"),
            arrayOf(ConnectionResult.API_UNAVAILABLE, "PLAY_SERVICES_UNAVAILABLE"),
            arrayOf(999, "PLAY_SERVICES_UNAVAILABLE"),
        )
    }
}
