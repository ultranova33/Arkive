# Arkive

Arkive is a privacy-first Flutter document vault for storing scanned land and property documents locally on iPhone.

The app is designed around local ownership: documents, metadata, categories, and generated PDFs remain inside the app's local storage. Arkive does not include a document export or sharing workflow.

## Features

- App lock using iOS authentication with passcode fallback.
- Automatic locking when the app becomes inactive or moves to the background.
- Camera-based document scanning with multi-page support.
- Local PDF generation from scanned pages.
- Local PDF viewing with page navigation.
- SQLite metadata storage for:
  - Document title
  - Category
  - File path
  - Page count
  - File size
  - Creation date
- Built-in categories:
  - Land Deeds
  - Property Tax
  - Identity
  - Contracts
- User-created custom categories saved in SQLite.
- Case-insensitive title search.
- Case-insensitive category filtering.
- Light and dark themes.
- iCloud backup exclusion for generated PDF files.
- Custom Arkive iOS launcher icon.
- Delete confirmation that removes both metadata and the local PDF file.

## Privacy Model

Arkive stores generated PDFs in the iOS application documents directory and marks them as excluded from iCloud backup. The SQLite database is also stored in the application documents directory.

The current app does not provide document sharing or export. Removing a document deletes its database record and local file from the device.

## Technology

- Flutter and Dart
- `local_auth` for app authentication
- `cunning_document_scanner` for camera scanning
- `pdf` for PDF generation
- `flutter_pdfview` for local PDF viewing
- `sqflite` for local metadata storage
- `path_provider` for application storage paths
- `google_fonts` for Inter and Lexend typography
- `flutter_launcher_icons` for iOS icon generation

## Project Structure

```text
lib/
  database_helper.dart       SQLite database and migrations
  main.dart                  Arkive app root and theme configuration
  screens/
    home_screen.dart         Search, filters, scanning, and document list
    lock_screen.dart         Authentication entry screen
    pdf_viewer_screen.dart   Local PDF viewer
  services/
    auth_service.dart        Authentication and lifecycle lock state
    document_service.dart    PDF compilation and local backup exclusion
assets/
  icon/arkive_icon.png       Source launcher icon
ios/Runner/
  AppDelegate.swift          iOS backup-exclusion method channel
```

## Requirements

- Flutter stable
- Dart SDK compatible with the version in `pubspec.yaml`
- Xcode and CocoaPods for iOS builds
- An Apple device or simulator for iOS testing

The iOS deployment target is configured for iOS 13 or newer, subject to Flutter/Xcode updates applied during the build.

## Local Development

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run on an available device:

```bash
flutter run
```

## App Icon

The source icon is stored at:

```text
assets/icon/arkive_icon.png
```

Regenerate the native iOS icon set after changing the source image:

```bash
flutter pub get
dart run flutter_launcher_icons
```

Generated files are placed in:

```text
ios/Runner/Assets.xcassets/AppIcon.appiconset
```

## iOS Permissions

Arkive declares the following iOS permissions:

- Camera: required to scan land documents locally.
- Photo library: required for local document scan storage behavior.

## Codemagic Build

The repository includes `codemagic.yaml` with an unsigned iOS release workflow. It:

1. Installs Flutter dependencies.
2. Builds the iOS release with `--no-codesign`.
3. Packages `Runner.app` into an IPA payload.
4. Publishes `Arkive.ipa` as a Codemagic artifact.

The resulting unsigned IPA must be signed before installation. Tools such as Sideloadly can be used for local sideloading with a suitable Apple signing setup.

## Current Scope

Arkive currently focuses on secure local capture, organization, and viewing of documents. Cloud synchronization, accounts, document export, sharing, and remote backup are intentionally outside the current scope.
