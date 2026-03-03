//lib/services/api_service.dart

//🔧 Hinweise:
//Ersetze https://dein-api-server.de/api/artikel durch die URL deiner API.
//Die Klasse unterstützt:
//Abrufen der Artikelliste
//Senden eines Artikels (POST)
//Löschen eines Artikels (DELETE)
//

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artikel_model.dart';

class ApiService {
  final String baseUrl = 'https://dein-api-server.de/api/artikel';

  Future<List<Artikel>> fetchArtikelListe() async {
    final response = await http.get(Uri.parse(baseUrl))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Timeout beim Laden der Artikelliste (30s)'),
        );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Artikel.fromMap(json)).toList();
    } else {
      throw Exception('Fehler beim Laden der Artikelliste (Status: ${response.statusCode})');
    }
  }

  Future<void> sendArtikel(Artikel artikel) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(artikel.toMap()),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout beim Senden des Artikels (30s)'),
    );

    if (response.statusCode != 200) {
      throw Exception('Fehler beim Senden des Artikels (Status: ${response.statusCode})');
    }
  }

  Future<void> deleteArtikel(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Timeout beim Löschen des Artikels (15s)'),
        );

    if (response.statusCode != 200) {
      throw Exception('Fehler beim Löschen des Artikels (Status: ${response.statusCode})');
    }
  }
}
