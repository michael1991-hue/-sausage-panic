# TestFlight setup

## Create the Apple app

Register an explicit App ID in Apple Developer with **com.michaelwaters.sausagepanic**. No optional capabilities are needed for this offline prototype. Then create an app in App Store Connect:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Sausage Panic (subject to name availability) |
| Primary language | English (U.K.) |
| Bundle ID | com.michaelwaters.sausagepanic |
| SKU | SAUSAGEPANIC001 |

The app record and uploaded build must have the same bundle ID. The 1024×1024 opaque icon is included in the asset catalog and delivered with the build.

## Connect GitHub signing

In this repository's **Settings → Secrets and variables → Actions**, add:

| Type | Name | Value |
|---|---|---|
| Variable | APPLE_TEAM_ID | Your Apple Developer team ID |
| Secret | IOS_DISTRIBUTION_P12_BASE64 | Base64-encoded Apple Distribution certificate exported as .p12 **including its private key** |
| Secret | IOS_DISTRIBUTION_P12_PASSWORD | The password chosen when exporting that .p12 |
| Secret | IOS_PROFILE_BASE64 | Base64-encoded App Store Connect distribution .mobileprovision for this bundle ID, matching that distribution certificate |
| Secret | ASC_KEY_ID | App Store Connect team API key ID |
| Secret | ASC_ISSUER_ID | That key's issuer ID |
| Secret | ASC_PRIVATE_KEY_BASE64 | Base64-encoded AuthKey_KEYID.p8 downloaded when creating the team API key |

Use an API key with permission to upload builds for this app (App Manager is appropriate for this workflow). Add secret values directly to GitHub; do not commit them or send them in chat. The game provisioning profile must be specific to this app; a profile for another app will not work. Never revoke another app's working signing assets as part of this setup.

On a Mac, `base64 -i FILE | pbcopy` copies a file's encoded contents for pasting into the corresponding GitHub secret. The .p12 must be exported from Keychain Access together with its matching private key. Generate the distribution profile in Apple Developer using the same certificate and this app's explicit ID.

## Run the upload

Open **Actions → Upload to TestFlight → Run workflow → main** after the app record and credentials are configured. The workflow runs only on manual dispatch, selects an installed stable Xcode 26+ release, tests the core, validates the profile, signs an archive, validates the IPA with Apple and uploads it. Signing materials are removed from the temporary runner when it exits. The `testflight` GitHub environment can be configured with protection rules if desired.

Successful upload is not the same as TestFlight availability: wait for Apple processing, then configure test information and add the processed build to a testing group in App Store Connect. External testing may require beta review. This workflow does not submit a public App Store release or invite testers.

## Status

The initial simulator build and six core tests passed in GitHub Actions. The icon and identifier changes receive a new simulator check. A signed archive and Apple upload cannot be verified until your signing credentials and app record are configured. Physical-device gameplay still needs testing.

## Official references

- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Upload builds and supported Xcode versions](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
