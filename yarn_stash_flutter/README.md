# yarn_stash

A new Flutter project.

## Firebase configuration

Firebase API keys are provided at build time so real keys are not committed to
GitHub. Ravelry API credentials are not part of the Flutter build; they are
stored as Firebase Functions secrets and read only by the backend function.

1. Copy `firebase.env.example.json` to `firebase.env.json`.
2. Put your Android and iOS Firebase API keys in `firebase.env.json`.
3. Run the app with:

```sh
flutter run --dart-define-from-file=firebase.env.json
```

If you prefer not to use a file, pass the keys directly:

```sh
flutter run --dart-define=FIREBASE_ANDROID_API_KEY=your-android-key --dart-define=FIREBASE_IOS_API_KEY=your-ios-key
```

## Ravelry catalog function

The app calls the `ravelryYarnCatalog` callable Firebase Function to search
Ravelry. The function can be called without a signed-in app user. Set these
secrets once per Firebase project before deploying:

```sh
firebase functions:secrets:set RAVELRY_API_KEY
firebase functions:secrets:set RAVELRY_API_SECRET
firebase deploy --only functions:ravelryYarnCatalog
```

For Gen 2 callable functions, the backing Cloud Run service must allow public
invocation so Firebase client SDK callable requests can reach the function. If
catalog searches fail with Cloud Run authorization errors in function logs, grant
the `ravelryyarncatalog` service `roles/run.invoker` for `allUsers`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
