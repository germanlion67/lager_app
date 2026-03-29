# Prompt: M-009 Login-Flow & Authentifizierung

## Kontext

Die Lager-App (Flutter) nutzt PocketBase als Backend. Aktuell haben alle
PocketBase-Collections (`artikel`, `attachments`) **offene API-Regeln** —
jeder kann ohne Authentifizierung lesen und schreiben.

Für Produktionsumgebungen mit öffentlichem Zugang muss ein Login-Flow
implementiert werden.

## Vorhandene Infrastruktur

Der `PocketBaseService` (Singleton) hat bereits folgende Methoden:

```dart
// In lib/services/pocketbase_service.dart:
bool get isAuthenticated    // Prüft authStore.isValid
String? get currentUserId   // Record-ID des eingeloggten Users
Future<bool> login(String email, String password)  // authWithPassword
void logout()               // authStore.clear()
Die artikel_erfassen_screen.dart setzt bereits owner wenn authentifiziert:


    
if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
  body['owner'] = _pbService.currentUserId;
}
ⓘ
For code that is intended to be used in Siemens products or services, the code generation features of our AI Services may only be used after prior approval of your responsible organizational unit.
Ein User wurde bereits erstellt:

Email: user@lager.app
Passwort: changeme123
Aufgaben
1. Login-Screen erstellen
Neuer Screen: lib/screens/login_screen.dart
E-Mail + Passwort Eingabefelder mit Validierung
"Anmelden"-Button mit Loading-State
Fehlermeldung bei ungültigen Credentials
Optional: "Passwort vergessen" (PocketBase unterstützt das)
2. App-Start-Logik anpassen
In main.dart: Nach PocketBase-Initialisierung prüfen ob User eingeloggt ist
Wenn nicht eingeloggt → Login-Screen anzeigen
Wenn eingeloggt → normale App anzeigen
Auth-Token wird automatisch von PocketBase im authStore persistiert
3. Auto-Login
PocketBase authStore speichert Token automatisch
Beim App-Start: isAuthenticated prüfen
Token-Refresh implementieren (PocketBase Tokens laufen ab)
4. Logout
Logout-Button im Settings-Screen
PocketBaseService().logout() aufrufen
Zurück zum Login-Screen navigieren
5. API-Regeln verschärfen
PocketBase Migration erstellen die Regeln auf Auth setzt:
artikel: @request.auth.id != ''
attachments: @request.auth.id != ''
Rollback-Migration beibehalten (Regeln auf offen)
6. Registrierung (optional)
Entscheiden ob Selbst-Registrierung erlaubt sein soll
Oder ob nur Admins User erstellen können
Datei	Änderung
lib/screens/login_screen.dart	NEU — Login-UI
lib/main.dart	Auth-Check nach Initialisierung
lib/screens/settings_screen.dart	Logout-Button
lib/services/pocketbase_service.dart	Token-Refresh, Auto-Login
server/pb_migrations/	NEU — Auth-Regeln Migration
CHANGELOG.md	Dokumentation
docs/OPTIMIZATIONS.md	M-009 als erledigt markieren
Architektur-Entscheidungen
Kein separater Auth-Service: PocketBaseService hat bereits alle Methoden
Kein Provider/Bloc: Singleton-Pattern beibehalten (konsistent mit Rest der App)
Token-Persistierung: PocketBase authStore macht das automatisch
Kein OAuth/Social Login: Nur E-Mail + Passwort (KISS-Prinzip)
Akzeptanzkriterien
Login-Screen wird angezeigt wenn nicht eingeloggt
Nach Login: Normale App wird angezeigt
Nach App-Neustart: Automatisch eingeloggt (Token gültig)
Logout im Settings-Screen funktioniert
Artikel erstellen/bearbeiten funktioniert mit Auth
Attachments hochladen/löschen funktioniert mit Auth
API-Regeln erfordern Auth (Migration vorhanden)
Rollback-Migration setzt Regeln auf offen zurück
