# ✅ Projekt-Status & Roadmap

Diese Checkliste dokumentiert den aktuellen Fortschritt der **Lager_app** und die noch ausstehenden Aufgaben.

---

## 📊 Gesamtfortschritt
- **Phase 1: Grundlagen** (100% ✅)
- **Phase 2: Deployment & Security** (100% ✅)
- **Phase 3: Performance & Optimierung** (90% 🟡)
- **Phase 4: Multi-Plattform & Politur** (40% 🔴)

---

## 🛠️ Aktueller Status

### 1. Architektur & Core
- [x] PocketBase Schema & API Rules (K-002)
- [x] Automatische Initialisierung (Setup-Flow)
- [x] Zentrale Konfiguration (AppConfig, AppTheme, AppImages)
- [x] Logging-System (AppLogService)
- [x] Eindeutige Artikelnummern (1000+)

### 2. Deployment & CI/CD
- [x] Docker-Produktions-Setup (NPM + Caddy)
- [x] Härtung (CSP, HSTS, Network Isolation)
- [x] GitHub Actions: Release-Workflow für Android & Windows
- [x] GitHub Actions: Docker-Build & Push

### 3. Plattformen & Testing
- [x] Web (Chrome) — Voll funktionsfähig
- [x] Linux Desktop — Build & PDF-Export stabil
- [x] Windows Desktop — Build & Export stabil
- [ ] iOS/macOS — **Zurückgestellt** (Erfordert Apple Developer Account)

---

## 🚀 Offene Aufgaben (Roadmap)

### Priorität: HOCH (Kritische Features)
- [ ] **M-007**: Konfliktlösung bei Synchronisation (Manueller UI-Screen)
- [ ] **M-002**: Komplette Bereinigung verbleibender `debugPrint`-Aufrufe (ca. 34 Stellen)
- [ ] **H-001**: Vollständiger Test der Kamera-Integration auf Android 13+

### Priorität: MITTEL (Wartbarkeit & UX)
- [ ] **O-004**: Migration restlicher hardcoded UI-Werte auf `AppTheme`
- [ ] **O-002**: Unit-Tests für `image_processing_utils` und `uuid_generator`
- [ ] **N-005**: Nextcloud-Backup-Workflow finalisieren und testen

---

## 🔍 Wartungs-Historie

| Datum | Status | Änderung |
|---|---|---|
| 2026-03-25 | 🟡 | Dokumentation modularisiert, README verschlankt. |
| 2026-03-24 | ✅ | Produktions-Hardening und Indizierung abgeschlossen. |
| 2026-03-23 | ✅ | Design-Tokens und Themes implementiert. |

---

[Zurück zur README](../README.md) | [Zu den Optimierungs-Details](MANUELLE_OPTIMIERUNGEN.md)