# rider_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Push

Firebase Cloud Messaging (D-19), same mechanism as `customer_app`. Each flavor
reads `android/app/src/<flavor>/google-services.json` (private, gitignored).
Place it with:

```bash
rider_app/tool/setup_firebase.sh --copy                # dev (Firebase project jivo-quick, app in.jivo.rider.dev)
rider_app/tool/setup_firebase.sh --copy --env staging  # when that project exists
rider_app/tool/setup_firebase.sh --remove              # back to push off
```

The script copies from `~/.config/jivo-quick-commerce/firebase/<env>/`, checks
that the file registers the flavor's package and prints file names only. The
Gradle build applies the google-services plugin only when a flavor has its
file. Without it the app builds and runs with push off (`NoopPushMessaging`);
offers still arrive on the rider socket and by polling. Behaviour (channels,
background offer alarm, taps, token lifecycle): `docs/04-rider-app.md` §5
"Push".
