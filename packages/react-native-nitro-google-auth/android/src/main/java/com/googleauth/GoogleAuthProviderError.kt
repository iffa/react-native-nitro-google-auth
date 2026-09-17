package com.googleauth

import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import com.google.android.gms.common.ConnectionResult
import com.margelo.nitro.googleauth.GoogleSignInAndroidDiagnostics
import com.margelo.nitro.googleauth.GoogleSignInError

// Matches CredentialProviderPlayServicesImpl.MIN_GMS_APK_VERSION in AndroidX Credentials 1.6.0-rc02.
internal const val MIN_GOOGLE_PLAY_SERVICES_VERSION = 230815045

internal fun credentialProviderError(
    error: GetCredentialProviderConfigurationException,
    playServicesStatus: Int,
    playServicesVersion: String?,
): GoogleSignInError {
    val (code, message) = when (playServicesStatus) {
        ConnectionResult.SERVICE_MISSING ->
            "PLAY_SERVICES_MISSING" to "Google Play services is not installed. Use another sign-in method."
        ConnectionResult.SERVICE_DISABLED ->
            "PLAY_SERVICES_DISABLED" to "Enable Google Play services in device settings and try again."
        ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED ->
            "PLAY_SERVICES_UPDATE_REQUIRED" to "Update Google Play services and try again."
        ConnectionResult.SERVICE_UPDATING ->
            "PLAY_SERVICES_UPDATING" to "Google Play services is updating. Try again when the update finishes."
        ConnectionResult.SERVICE_INVALID ->
            "PLAY_SERVICES_INVALID" to "This device does not have a valid Google Play services installation. Use another sign-in method."
        ConnectionResult.SUCCESS ->
            "CREDENTIAL_PROVIDER_UNAVAILABLE" to "Google Play services is available, but Credential Manager could not use a credential provider. Check the Android provider configuration."
        else ->
            "PLAY_SERVICES_UNAVAILABLE" to "Google Play services is unavailable. Use another sign-in method or try again later."
    }

    return GoogleSignInError(
        code = code,
        message = message,
        android = GoogleSignInAndroidDiagnostics(
            playServicesStatus = playServicesStatus.toDouble(),
            playServicesVersion = playServicesVersion,
            nativeExceptionType = error.javaClass.name,
            nativeMessage = error.message,
            nativeStackTrace = error.stackTraceToString(),
        ),
    )
}
