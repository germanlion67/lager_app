import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:barcode/barcode.dart';


void main() {
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


// =============================
// Datenmodell
// =============================
class LocationModel {
final int? id;
final String name;


const LocationModel({this.id, required this.name});


LocationModel copyWith({int? id, String? name}) =>
LocationModel(id: id ?? this.id, name: name ?? this.name);


factory LocationModel.fromMap(Map<String, Object?> map) => LocationModel(
id: map['id'] as int?,
name: map['name'] as String,
);


Map<String, Object?> toMap() => {
'id': id,
'name': name,
};
}


class ItemModel {
final int? id;
final int createdAt; // Unix ms
final int locationId;
final String name;
final String description;
final String? qrCode; // optionaler QR/Barcode-Text


const ItemModel({
this.id,
required this.createdAt,
Materi
