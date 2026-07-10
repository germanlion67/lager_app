// lib/services/auth_store_factory.dart
//
// F-012.6: Plattformspezifische AsyncAuthStore-Factory.
// Conditional import wählt automatisch Web- oder Native-Implementierung.

export 'auth_store_factory_native.dart'
    if (dart.library.html) 'auth_store_factory_web.dart';