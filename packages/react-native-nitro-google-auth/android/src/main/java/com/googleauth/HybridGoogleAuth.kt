package com.googleauth

import android.content.pm.PackageManager
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import com.margelo.nitro.googleauth.GoogleAuthConfig
import com.margelo.nitro.googleauth.GoogleSignInError
import com.margelo.nitro.googleauth.GoogleSignInResult
import com.margelo.nitro.googleauth.GoogleUserData
import com.margelo.nitro.googleauth.HybridGoogleAuthSpec

class HybridGoogleAuth : HybridGoogleAuthSpec() {
    private var authConfig = GoogleAuthConfig(
        iosClientId = null,
        webClientId = null,
    )

    override fun configure(config: GoogleAuthConfig) {
        authConfig = config
    }

    override fun signIn(): Promise<GoogleSignInResult> {
        return Promise.async {
            val reactContext = NitroModules.applicationContext
                ?: throw Error("React context is not available.")
            val webClientId = authConfig.webClientId?.trim()?.takeIf { it.isNotEmpty() }
                ?: throw Error(
                    "Missing webClientId on Android. Call GoogleAuth.configure({ webClientId: \"...\" }) before signIn()."
                )
            val activity = reactContext.currentActivity
                ?: throw Error("No foreground Activity available for Google sign-in.")
            val credentialManager = CredentialManager.create(reactContext)

            val credentialResponse = try {
                getGoogleCredentialForButtonFlow(
                    credentialManager = credentialManager,
                    webClientId = webClientId,
                    activityContext = activity
                )
            } catch (_: GetCredentialCancellationException) {
                return@async GoogleSignInResult(
                    data = null,
                    error =
                        GoogleSignInError(
                            code = "CANCELLED",
                            message = "The user canceled the sign-in flow.",
                            android = null,
                        ),
                )
            } catch (_: NoCredentialException) {
                return@async GoogleSignInResult(
                    data = null,
                    error =
                        GoogleSignInError(
                            code = "NO_CREDENTIALS",
                            message =
                                "No Google credentials available on this device. " +
                                    "Make sure a Google account is present and try again.",
                            android = null,
                        ),
                )
            } catch (error: GetCredentialProviderConfigurationException) {
                val playServicesStatus = GoogleApiAvailabilityLight.getInstance()
                    .isGooglePlayServicesAvailable(reactContext, MIN_GOOGLE_PLAY_SERVICES_VERSION)
                @Suppress("DEPRECATION")
                val playServicesVersion = try {
                    reactContext.packageManager.getPackageInfo("com.google.android.gms", 0).versionName
                } catch (_: PackageManager.NameNotFoundException) {
                    null
                }
                return@async GoogleSignInResult(
                    data = null,
                    error = credentialProviderError(error, playServicesStatus, playServicesVersion),
                )
            }

            val credential = credentialResponse.credential
            if (credential !is CustomCredential) {
                throw Error("Unexpected credential type returned from Credential Manager.")
            }

            if (credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL &&
                credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL
            ) {
                throw Error("Unsupported Google credential type: ${credential.type}")
            }

            val googleIdTokenCredential = try {
                GoogleIdTokenCredential.createFrom(credential.data)
            } catch (error: GoogleIdTokenParsingException) {
                throw Error("Failed to parse Google ID token credential: ${error.message}")
            }

            val idToken = googleIdTokenCredential.idToken
            if (idToken.isBlank()) {
                throw Error("Google sign-in did not return an idToken.")
            }

            GoogleSignInResult(
                data =
                    GoogleUserData(
                        idToken = idToken,
                        providerUserId = googleIdTokenCredential.uniqueId,
                        email = googleIdTokenCredential.email,
                        name = googleIdTokenCredential.displayName,
                        photoUrl = googleIdTokenCredential.profilePictureUri?.toString(),
                    ),
                error = null,
            )
        }
    }

    override fun signOut(): Promise<Unit> {
        return Promise.async {
            val reactContext = NitroModules.applicationContext
                ?: throw Error("React context is not available.")
            val credentialManager = CredentialManager.create(reactContext)
            credentialManager.clearCredentialState(ClearCredentialStateRequest())
        }
    }

    private suspend fun getGoogleCredentialForButtonFlow(
        credentialManager: CredentialManager,
        webClientId: String,
        activityContext: android.app.Activity
    ): GetCredentialResponse {
        val optionBuilder = GetSignInWithGoogleOption.Builder(webClientId)

        val signInWithGoogleOption = optionBuilder.build()
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(signInWithGoogleOption)
            .build()

        return credentialManager.getCredential(
            context = activityContext,
            request = request
        )
    }
}
