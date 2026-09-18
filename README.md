# Feedback & Review App

A cross-platform Flutter app (Android and iOS) for collecting, managing and analyzing feedback on tasks, courses and services. Users submit star ratings, reviews and suggestions; admins see everything in a real-time dashboard with filters and analytics.

- **Client:** Flutter
- **Backend:** Firebase Authentication and Cloud Firestore
- **State management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router`
- **Charts:** `fl_chart`

Product and technical scope live in [docs/PRD.md](docs/PRD.md) and [docs/TRD.md](docs/TRD.md).

## Getting started

1. Install the Flutter SDK (stable channel).
2. Run `flutter pub get`.
3. Run the app with `flutter run`.

## Folder structure

```
lib/
├── main.dart
├── app.dart                 # MaterialApp + theme
├── core/                    # router, theme, constants, utils
├── services/                # thin wrappers over Firebase Auth / Firestore
├── models/                  # plain Dart data classes
├── repositories/            # query logic, model <-> Firestore mapping
├── providers/               # Riverpod providers / notifiers
└── features/                # auth, items, feedback, admin, profile
```

## Testing

```
flutter analyze
flutter test
```
