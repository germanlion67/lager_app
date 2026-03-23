import 'package:flutter/material.dart';
import 'dart:async';

import 'package:runtime_env_config/runtime_env_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _pocketBaseUrl = 'Loading...';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Lädt die PocketBase-URL aus der Umgebung
  Future<void> initPlatformState() async {
    String pocketBaseUrl;
    try {
      final url = await RuntimeEnvConfig.pocketBaseUrl();
      pocketBaseUrl = url ?? 'No PocketBase URL configured';
    } catch (e) {
      pocketBaseUrl = 'Error loading config: $e';
    }

    // Nur setState aufrufen, wenn das Widget noch im Tree ist
    if (!mounted) return;

    setState(() {
      _pocketBaseUrl = pocketBaseUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Runtime Env Config Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('PocketBase URL:'),
              const SizedBox(height: 16),
              Text(
                _pocketBaseUrl,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}