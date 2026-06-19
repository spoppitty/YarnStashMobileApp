# yarn_stash

A new Flutter project.

## Firebase configuration

Firebase API keys are provided at build time so real keys are not committed to
GitHub.

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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
