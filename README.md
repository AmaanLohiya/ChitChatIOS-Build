# ChitChat Native iOS Build Mirror

This repository is a public build mirror containing only the native Swift/UIKit iOS application and the GitHub Actions workflow required to compile an unsigned IPA. It intentionally excludes the private backend, React Native/Expo application, environment files, deployment configuration, and private project documentation.

## Repository contents

- `ios-native/ChitChatIOS/ChitChatIOS.xcodeproj`: Xcode project
- `ios-native/ChitChatIOS/ChitChatIOS/`: Swift sources, `Info.plist`, and asset catalog
- `.github/workflows/ios-native-unsigned-ipa.yml`: manual unsigned IPA build

The app includes the current native iOS implementation for authentication, chats, contacts, text and media messaging, Socket.IO realtime updates, and one-to-one voice calling.

## Build the unsigned IPA

1. Open the repository on GitHub.
2. Select **Actions**.
3. Select **Build Native iOS Unsigned IPA**.
4. Choose **Run workflow**.
5. After the job completes, download the `ChitChatIOS-unsigned` artifact.

The artifact contains `ChitChatIOS-unsigned.ipa`. It is unsigned and is not ready for App Store or TestFlight distribution. Installation requires an appropriate sideloading or re-signing process.

## Demo backend

The native app currently targets the public demo backend at `http://156.67.105.161:8020`. This URL is intentionally committed and is not a secret. The app's development configuration permits HTTP traffic so it can reach that endpoint.

Production distribution should use an HTTPS domain and remove the broad HTTP transport exception.

## Local development

Open `ios-native/ChitChatIOS/ChitChatIOS.xcodeproj` in Xcode 15 or newer. Swift Package Manager resolves the Socket.IO and WebRTC dependencies referenced by the project.

Do not commit signing certificates, provisioning profiles, credentials, environment files, or generated build artifacts.
