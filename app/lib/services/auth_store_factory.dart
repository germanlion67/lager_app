// lib/services/auth_store_factory.dart
//
// F-012.6: Plattformspezifische AsyncAuthStore-Factory.
// Conditional import wählt automatisch Web- oder Native-Implementierung.
//
// WICHTIG: dart.library.js_interop statt dart.library.html verwenden!
// dart.library.html ist unter Flutter Web mit --wasm nicht verfügbar.
// dart.library.js_interop ist der korrekte Selector für WASM + JS-Targets.

export 'auth_store_factory_native.dart'
    if (dart.library.js_interop) 'auth_store_factory_web.dart';