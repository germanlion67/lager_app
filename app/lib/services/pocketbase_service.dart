// lib/services/pocketbase_service.dart
import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  // Liest die URL aus den Build-Arguments (--dart-define) oder nutzt Localhost als Fallback
  static const String _baseUrl = String.fromEnvironment(
    'PB_URL', 
    defaultValue: 'http://127.0.0.1:8090'
  );

  static final PocketBase client = PocketBase(_baseUrl);
  
  static String get url => _baseUrl;
}
