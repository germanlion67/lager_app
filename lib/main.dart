import 'package:flutter/material.dart';
import 'screens/item_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LagerApp());
}

class LagerApp extends StatelessWidget {
  const LagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lagerverwaltung',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const ItemListScreen(),
    );
  }
}
