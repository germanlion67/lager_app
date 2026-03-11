// lib/services/database_service.dart
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  // Ersetze 192.168.178.XX mit der IP deines Rechners im WLAN
  static final String baseUrl = kIsWeb 
      ? 'http://localhost:8090' 
      : 'http://192.168.178.XX:8090'; 

  static final pb = PocketBase(baseUrl);
}
