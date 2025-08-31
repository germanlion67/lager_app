import 'package:flutter/material.dart';
import 'screens/item_list_screen.dart';

void main() {
  runApp(const LagerApp());
}

class LagerApp extends StatelessWidget {
  const LagerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lagerverwaltung',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const ItemListScreen(),
    );
  }
}