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

## Firebase security rules

All access control lives in [firestore.rules](firestore.rules). The screens only
mirror it, so the rules are the real security boundary.

| Data | Who can do what |
|---|---|
| `users` | Read/create your own profile (always role `user`); change your own name. Only the **super admin** lists other users and changes roles (never their own, never granting `superAdmin`). |
| `items` | Any signed-in user reads. Admins create and edit them. Nobody deletes. |
| `feedback` | You create, edit and delete only your own (id is `{itemId}_{userId}`). Admins read all. |
| rating totals | An item's `ratingCount`, `ratingSum` and `averageRating` can only change in the same write as the caller's own feedback change, by exactly the amount that change implies. |

Roles are stored on `users/{uid}.role` as `user`, `admin` or `superAdmin`. The
super admin is set by hand once, in the Firebase console.

No composite indexes are needed: every query uses a single sort field or
equality filters only, and the rest is filtered on the device.

### Running the rules tests

The tests run against the local Firestore emulator and need **Node** and **Java
(11 or newer)** on your PATH, plus the Firebase CLI (`npm i -g firebase-tools`).

```
cd firestore_tests
npm install          # first time only
npm run test:emulator
```

The emulator downloads itself on the first run. No real Firebase project is
touched.

### Publishing the rules

Copy the contents of [firestore.rules](firestore.rules) into the Firebase
console under **Firestore Database -> Rules** and press **Publish**, or run
`firebase deploy --only firestore:rules` after `firebase login`.

