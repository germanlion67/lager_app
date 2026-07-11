# runtime_env_config

Flutter plugin for reading runtime configuration from `window.ENV_CONFIG` in
Flutter Web builds.

## Getting Started

This package is used by `lager_app` to keep Web-only interop out of the app
layer. The current implementation supports the **Web** platform and exposes:

- `RuntimeEnvConfig.pocketBaseUrl()` → reads `window.ENV_CONFIG.POCKETBASE_URL`

Example:

```dart
final url = await RuntimeEnvConfig.pocketBaseUrl();
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on Flutter development, and a full API reference.
