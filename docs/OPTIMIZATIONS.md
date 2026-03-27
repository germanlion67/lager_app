# 🛠️ Technische Optimierungen & Offene Punkte

Dieses Dokument beschreibt spezifische technische Aufgaben, Refactorings und „Politur-Arbeiten“, die für den Abschluss der nächsten Projektphasen notwendig sind.

**Zuletzt aktualisiert:** v0.7.0 (27.03.2026)

---

## ✅ Abgeschlossen

### K-001: Bundle Identifiers — Erledigt
- Android: `com.germanlion67.lagerverwaltung` ✅
- iOS: `com.germanlion67.lagerverwaltung` ✅

### K-004: Runtime-Konfiguration PocketBase-URL — Erledigt in v0.7.0
- Setup-Screen beim Erststart ✅
- URL-Prioritätskette  
  (`SharedPreferences` → Runtime-Config → `dart-define` → Setup-Screen) ✅
- Kein Crash bei fehlender URL ✅

### O-001: Bereinigung von `debugPrint` — Erledigt
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt ✅
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich  
  *(zirkuläre Abhängigkeit — der Logger kann sich nicht selbst zum Loggen verwenden)* ✅

### M-002: AppLogService Integration — Erledigt in v0.3.0
- Konsistentes Logging im gesamten Projekt ✅

### N-004: Roboto Font — Erledigt in v0.3.0
- Roboto als Standard-Schriftart via `google_fonts` ✅

### M-007 (alt): Artikelnummer & Indizes — Erledigt in v0.3.0
- Eindeutige Artikelnummer ✅
- 5 Performance-Indizes ✅

---

## 🔴 Priorität: Hoch

### H-002: CORS-Konfiguration
PocketBase CORS muss für Produktion auf die tatsächliche Domain eingeschränkt werden.  
Aktuell ist `*` (alle Origins) möglich.

**Aufgaben:**
- PocketBase-Settings: `Access-Control-Allow-Origin` auf `https://lager.deine-domain.de` einschränken
- Testen, ob Web-Frontend und Mobile-App weiterhin funktionieren
- Dokumentation in `DEPLOYMENT.md` ergänzen

### H-003: Backup-Automatisierung
Backup-Methoden sind dokumentiert (`DEPLOYMENT.md`), aber es gibt kein fertiges, getestetes Script.

**Aufgaben:**
- `scripts/backup.sh` erstellen *(PocketBase-Backup + Volume-Tar)*
- Cron-Beispiel mit Rotation *(z. B. 7 Tage behalten)*
- Restore-Anleitung testen und dokumentieren

### M-007: UI für Konfliktlösung
Der Synchronisations-Prozess erkennt Konflikte, aber die Benutzeroberfläche zur Auswahl zwischen  
**„Lokal behalten“** oder **„Server übernehmen“** ist noch nicht finalisiert.

**Aufgaben:**
- `conflict_resolution_screen.dart` fertigstellen
- Vergleichs-Widget *(Vorher/Nachher)* für Artikeldaten implementieren

---

## 🟡 Priorität: Mittel

### O-004: UI-Hardcoded Werte migrieren
Es gibt noch ca. 140 Stellen im Code, an denen Farben, Abstände oder Radien direkt *(hardcoded)* vergeben sind, statt `AppConfig` oder `AppTheme` zu nutzen.

**Fokus-Bereiche:**
- `sync_progress_widgets.dart`
- `artikel_list_item_widget.dart`
- `settings_screen.dart`

**Standard-Werte verwenden:**
- Abstände: `AppConfig.spacingMedium` (`16.0`)
- Ecken: `AppConfig.cardBorderRadius` (`12.0`)
- Farben: `Theme.of(context).colorScheme.primary`

### O-002: Unit-Tests für Core-Utilities
Einige kritische Hilfsfunktionen sind noch nicht durch automatisierte Tests abgedeckt.

**Zu testende Komponenten:**
- `uuid_generator.dart`: Sicherstellen der Eindeutigkeit
- `image_processing_utils.dart`: Prüfung der Kompression *(Größe vor/nachher)*
- `artikel_model.dart`: Validierung von `fromMap` / `toMap` *(besonders für Null-Werte)*

### M-003: Error Handling
Einheitliche Fehlerbehandlung in der gesamten App. Aktuell werden Fehler unterschiedlich behandelt  
(`try/catch` mit verschiedenen Patterns, teils ohne User-Feedback).

**Aufgaben:**
- Einheitliches Error-Handling-Pattern definieren  
  *(z. B. Result-Type oder Exception-Klassen)*
- `SnackBar` / Dialog für Benutzerfehler konsistent einsetzen
- Netzwerkfehler von Anwendungsfehlern unterscheiden

### M-004: Loading States
Konsistente Lade-Indikatoren in allen Screens. Aktuell fehlen in einigen Screens Loading-Spinner oder Skeleton-Loader.

**Aufgaben:**
- Alle Async-Operationen mit Loading-State versehen
- Einheitliches Loading-Widget *(z. B. `LoadingOverlay`)* erstellen
- Leere Listen mit Placeholder-Widget darstellen

### M-005: Pagination
Die Artikelliste lädt aktuell alle Einträge auf einmal. Bei mehr als 100 Artikeln wird das spürbar langsam.

**Aufgaben:**
- `ListView.builder` mit Lazy-Loading implementieren
- PocketBase-Pagination nutzen (`page`, `perPage` Parameter)
- „Mehr laden“-Indikator am Listenende

### M-006: Input Validation
Formulare in der App sind nicht vollständig validiert.

**Aufgaben:**
- Pflichtfelder markieren und validieren
- Artikelnummer: Bereichsprüfung (`1–99999`), Duplikat-Check
- Mengenfelder: Nur positive Zahlen erlauben
- URL-Felder: Format-Validierung

---

## 🟢 Priorität: Nice-to-Have

### N-003: App Icon
Noch das Flutter-Default-Icon. Ein eigenes App-Icon verbessert die Wiedererkennung.

**Aufgaben:**
- Icon-Design erstellen (`1024x1024` PNG)
- `flutter_launcher_icons` Package nutzen
- Android Adaptive Icon konfigurieren
- iOS Icon-Set generieren

### N-005: Splash Screen
Noch der Standard-Flutter-Splash-Screen.

**Aufgaben:**
- `flutter_native_splash` Package konfigurieren
- Splash-Screen mit App-Logo und Hintergrundfarbe
- Für Android 12+ Splash-Screen-API berücksichtigen

### N-006: Nextcloud-Workflow
Die WebDAV-Anbindung ist funktional, aber der automatische Upload nach einem erfolgreichen Sync ist noch als „experimentell“ markiert.

**Aufgaben:**
- Testlauf mit einer realen Nextcloud-Instanz *(Version 28+)*  
- Fehlerbehandlung bei fehlendem Speicherplatz oder abgelaufenen App-Passwörtern verbessern

### H-001 (alt): iOS/macOS Vorbereitung
Falls ein Apple Developer Account verfügbar wird, sind folgende Schritte in `app/ios/` notwendig:

**Aufgaben:**
- `Runner.xcworkspace` in Xcode öffnen
- App Groups für geteilten Speicher *(Sync)* konfigurieren
- `Info.plist`-Beschreibungen für Kamera und Galerie prüfen