# Release Signing

Luno is distributed outside the Mac App Store, so release builds should use a
Developer ID Application certificate and Apple notarization.

## Requirements

- Active Apple Developer Program membership.
- Access to App Store Connect with permission to notarize.
- A `Developer ID Application` certificate and private key in your keychain.
- An Apple ID app-specific password for `notarytool`.

App Store Connect access alone is not enough if the Apple Developer Program
membership or Developer ID certificate access is missing.

## Local Signed DMG

Build and sign the app and DMG:

```bash
scripts/package-release.sh 0.1.0
```

The script automatically uses the first available `Developer ID Application`
identity unless `LUNO_CODESIGN_IDENTITY` is set:

```bash
LUNO_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  scripts/package-release.sh 0.1.0
```

Notarize the DMG:

```bash
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
  scripts/notarize-release.sh 0.1.0
```

## GitHub Actions Secrets

To sign and notarize release builds in GitHub Actions, add these repository
secrets:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `LUNO_CODESIGN_IDENTITY` optional, when more than one Developer ID identity is
  available.

Export a `.p12` certificate from Keychain Access, then encode it:

```bash
base64 < DeveloperIDApplication.p12 | pbcopy
```

Paste the copied value into `APPLE_CERTIFICATE_BASE64`.

## Verification

```bash
codesign --verify --strict --deep --verbose=2 .build/artifacts/Luno.app
hdiutil verify dist/Luno-v0.1.0-macOS-arm64.dmg
spctl -a -vvv -t open --context context:primary-signature dist/Luno-v0.1.0-macOS-arm64.dmg
```
