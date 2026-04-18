# Fix: Login und Sync Hängen-Problem

## Problem
Die Mobile App (Android APK) hatte zwei kritische Probleme:

1. **Login mit korrekten Zugangsdaten zeigt keine Reaktion**
   - Login-Button wird gedrückt
   - Keine Fehlermeldung
   - App bleibt auf Login-Screen hängen

2. **Nach Server-Setup hängt "Erstmalige Synchronisation..."**
   - Nach Neuinstallation erscheint Server-Setup-Screen
   - PocketBase URL wird eingegeben
   - Verbindungstest erfolgreich
   - "Erstmalige Synchronisation..." Overlay erscheint und hängt sich auf

## Ursache
Der initiale Sync (`_runInitialSync()`) wurde **synchron** im UI-Thread ausgeführt:

```dart
// VORHER (falsch):
await _runInitialSync();  // ← blockiert UI-Thread
```

Der Sync-Prozess führt folgende Operationen durch:
1. `syncOnce()` - Push/Pull aller Artikel-Daten
2. `downloadMissingImages()` - Download aller Produktbilder

Bei vielen Artikeln oder langsamer Verbindung kann das **mehrere Minuten** dauern und blockiert währenddessen komplett den UI-Thread.

## Lösung
Der Sync wird jetzt **asynchron im Hintergrund** ausgeführt:

```dart
// NACHHER (richtig):
unawaited(_runInitialSync());  // ← läuft im Hintergrund
```

### Änderungen im Detail

#### 1. `main.dart` - `_onLoginSuccess()` (Zeile 367-382)
```dart
void _onLoginSuccess() {
  _log.i('[Auth] Login erfolgreich, starte App...');
  setState(() => _isLoggedIn = true);  // ← UI wird SOFORT aktualisiert

  // Konflikt-Callback registrieren
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _registerConflictCallback();
  });

  // FIX: Sync asynchron im Hintergrund starten
  if (_pbService.hasClient && !kIsWeb) {
    _loadSyncSettings().then((_) {
      unawaited(_runInitialSync());  // ← nicht mehr blockierend
      _startPeriodicSync();
    });
  }
}
```

**Effekt:**
- Login → App erscheint **sofort**
- Sync läuft **unsichtbar** im Hintergrund
- User kann sofort mit der App arbeiten

#### 2. `main.dart` - `_onServerConfigured()` (Zeile 455-491)
```dart
void _onServerConfigured() {
  _log.i('[Main] Server konfiguriert, starte initialen Sync...');

  if (_pbService.hasClient) {
    // ... Orchestrator neu erstellen ...

    _checkAuthStatus().then((_) {
      // FIX: Setup-Screen SOFORT schließen
      if (mounted) {
        setState(() => _needsSetup = false);  // ← Setup-Screen wird geschlossen
      }

      // Dann Sync im Hintergrund
      if ((_isLoggedIn || _devMode) && !kIsWeb) {
        _loadSyncSettings().then((_) {
          _log.i('[Main] Starte initialen Sync nach Setup...');
          unawaited(_runInitialSync().then((_) {  // ← asynchron
            _log.i('[Main] Initialer Sync abgeschlossen');
          }));
          _startPeriodicSync();
        });
      }
    });
  }
}
```

**Effekt:**
- Server-Setup → Setup-Screen schließt **sofort**
- Sync läuft **unsichtbar** im Hintergrund
- User sieht sofort Login-Screen oder App

#### 3. `server_setup_screen.dart` - Sync-Overlay entfernt
Das "Erstmalige Synchronisation..." Overlay wurde komplett entfernt:

```dart
// VORHER (entfernt):
bool _isSyncingAfterSetup = false;

if (_isSyncingAfterSetup)
  Positioned.fill(
    child: Container(
      // ... Overlay mit "Erstmalige Synchronisation..."
    ),
  ),
```

**Effekt:**
- Kein blockierendes Overlay mehr
- User kann sofort weiterarbeiten

## Testen

### Voraussetzungen
- WSL2 Debian mit Flutter SDK
- Android Device/Emulator
- PocketBase Server läuft

### Test 1: Login nach App-Start
```bash
# 1. APK bauen
cd app
flutter build apk --release

# 2. APK auf Gerät installieren
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. App öffnen und testen:
#    - Mit korrekten Zugangsdaten einloggen
#    - Erwartung: App öffnet sich SOFORT (nicht mehr hängend)
#    - Sync läuft im Hintergrund (sichtbar in Logs)
```

### Test 2: Server-Setup nach Neuinstallation
```bash
# 1. App deinstallieren
adb uninstall de.germanlion.lagerapp  # oder dein package name

# 2. App neu installieren
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. App öffnen und testen:
#    - PocketBase URL eingeben
#    - "Verbindung testen" → sollte erfolgreich sein
#    - "Weiter" klicken
#    - Erwartung: Setup-Screen schließt SOFORT (kein Overlay mehr)
#    - Login-Screen erscheint
#    - Nach Login: App öffnet sich SOFORT
```

### Logs überwachen
```bash
# Terminal 1: Flutter Logs
flutter run -d <device-id> --verbose

# Terminal 2: Android Logs (optional)
adb logcat | grep -i "sync\|login\|auth"
```

**Wichtige Log-Einträge:**
```
[Auth] Login erfolgreich, starte App...
[Sync] Initialer Sync startet...
PocketBaseSync: syncOnce start (collection=artikel)
PocketBaseSync: downloadMissingImages start
PocketBaseSync: downloadMissingImages end (downloaded: X, skipped: Y, failed: Z)
[Sync] Initialer Sync abgeschlossen
```

## Erwartetes Verhalten

### ✅ Login-Flow (Erfolg)
1. User gibt Zugangsdaten ein → klickt "Anmelden"
2. **SOFORT:** Login-Screen verschwindet, App öffnet sich
3. **Hintergrund:** Sync läuft (sichtbar in Logs, nicht im UI)
4. Nach wenigen Sekunden/Minuten: Artikel-Liste ist synchronisiert

### ✅ Server-Setup-Flow (Erfolg)
1. User gibt PocketBase URL ein → klickt "Verbindung testen"
2. Verbindung OK → klickt "Weiter"
3. **SOFORT:** Setup-Screen schließt sich
4. Login-Screen erscheint
5. Nach Login: App öffnet sich **SOFORT**
6. **Hintergrund:** Sync läuft (sichtbar in Logs)

### ❌ Altes Verhalten (Bug, jetzt behoben)
1. User gibt Zugangsdaten ein → klickt "Anmelden"
2. **PROBLEM:** Login-Screen bleibt sichtbar, keine Reaktion
3. **URSACHE:** Sync blockiert UI-Thread
4. Nach Minuten: Entweder Timeout oder App öffnet sich endlich

## Weitere Verbesserungen (Optional)

Falls gewünscht, könnten folgende Features hinzugefügt werden:

### 1. Sync-Status-Indikator in der App
```dart
// In ArtikelListScreen einen kleinen Badge zeigen:
if (isSyncing) {
  Badge(
    label: Text('Sync läuft...'),
    child: Icon(Icons.sync),
  )
}
```

### 2. Sync-Progress im Setup
```dart
// Kleine Snackbar nach Server-Setup:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Initiale Synchronisation läuft im Hintergrund...'),
    duration: Duration(seconds: 3),
  ),
);
```

### 3. Sync-Fehler-Handling
```dart
// Wenn Sync fehlschlägt, Benachrichtigung zeigen:
if (syncError) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Synchronisation fehlgeschlagen. Erneut versuchen?'),
      action: SnackBarAction(
        label: 'Wiederholen',
        onPressed: () => _runInitialSync(),
      ),
    ),
  );
}
```

Diese Features würden die User-Experience verbessern, sind aber optional.

## Zusammenfassung

**Problem:** Login und Server-Setup hingen sich auf wegen blockierendem Sync.

**Lösung:** Sync läuft jetzt asynchron im Hintergrund mit `unawaited()`.

**Resultat:** 
- ✅ Login funktioniert sofort
- ✅ Server-Setup schließt sofort
- ✅ App ist sofort verwendbar
- ✅ Sync läuft unsichtbar im Hintergrund
- ✅ Keine Blockierung mehr

**Dateien geändert:**
- `app/lib/main.dart` (2 Funktionen)
- `app/lib/screens/server_setup_screen.dart` (Overlay entfernt)

**Commit:** `79970ab` - "Fix: Login und Sync non-blocking - UI wird nicht mehr blockiert"
