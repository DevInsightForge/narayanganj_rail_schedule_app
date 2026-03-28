# Google Play Compliance Review (Pre-Release)

_Last reviewed: March 27, 2026._

## App Identity

- **Android application ID**: `com.devinsightforge.narayanganjcommuter`
- **Android namespace**: `com.devinsightforge.narayanganjcommuter`

## Current Technical Compliance Posture

### Permissions and user data

- No dangerous Android runtime permissions are declared in `AndroidManifest.xml`.
- The app stores user route selections locally using shared preferences.
- The app fetches schedule JSON from an HTTPS endpoint.

### Network and platform hardening

- `android:usesCleartextTraffic="false"` is enabled to block HTTP traffic.
- `android:allowBackup="false"` is enabled to avoid automatic cloud backup of local app data.

## Play Console Setup Checklist

Before publishing, confirm the following in Play Console:

1. **App content**
   - Fill in Data safety form accurately (local preferences + remote schedule fetch).
   - Complete target audience and content rating questionnaires.
2. **Privacy policy**
   - Provide a hosted privacy policy URL in Play Console if any user data handling applies in your jurisdiction.
3. **Store listing integrity**
   - Ensure screenshots, short description, and full description are accurate and non-misleading.
4. **Release security**
   - Use a secure release keystore and rotate credentials according to org policy.
5. **Policy updates**
   - Re-review active Google Play policy changes before each production release.

## Recommendation

Keep this checklist as part of release gating (CI/CD or release template) to reduce policy rejection risk.
