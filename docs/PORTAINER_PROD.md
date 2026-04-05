# 🐳 Portainer Prod Setup (NPM läuft auf anderem Rechner)

Stand: 2026-04-05  
Ziel: PocketBase (API) ist über **https://api.germanlion67.de** erreichbar, damit **Mobile/Tablet/Desktop** die Datenbank nutzen können.  
Dein aktuelles Setup: Portainer Stack veröffentlicht Ports **8080/8081** auf dem Server, Nginx Proxy Manager (NPM) läuft **auf einem anderen Rechner**.

---

## ✅ Überblick

- **PocketBase API (für Mobile wichtig):** `https://api.germanlion67.de` → (NPM) → `http://<SERVER-IP>:8080`
- **Web-Frontend (optional):** `https://lager.germanlion67.de` → (NPM) → `http://<SERVER-IP>:8081`

> Mobile braucht nur die **API-Domain**. CORS ist nur für Browser relevant.

---

## 1) DNS einrichten (Pflicht)

Bei deinem DNS-Provider einen **A-Record** setzen:

- **Host/Name:** `api`
- **Typ:** `A`
- **Wert:** `<DEINE_SERVER_IP>`

(Optional fürs Web-Frontend)

- **Host/Name:** `lager`
- **Typ:** `A`
- **Wert:** `<DEINE_SERVER_IP>`

Prüfen (von irgendwo im Internet):

```bash
nslookup api.germanlion67.de
# sollte auf <DEINE_SERVER_IP> zeigen
```

---

## 2) Firewall / Router / Security Group (Pflicht)

Da NPM auf einem anderen Rechner läuft und Let's Encrypt nutzt:

Auf dem **Lager-App-Server** müssen erreichbar sein:

- TCP **8080** (PocketBase Port-Mapping aus deinem Stack)
- TCP **8081** (Web Port-Mapping aus deinem Stack, optional aber meist sinnvoll)

Auf dem **NPM-Rechner** müssen erreichbar sein:

- TCP **80**
- TCP **443**

> Wichtig: **Port 80/443 muss auf den NPM-Rechner zeigen** (weil dort die Zertifikate terminiert werden).
> Das ist bei dir bereits offen.

---

## 3) Portainer: Environment Variables setzen (UI) (Pflicht/Empfohlen)

Portainer → **Stacks** → dein Stack → **Environment variables**.

### Pflicht
- `PB_ADMIN_PASSWORD` = `<SEHR_STARKES_PASSWORT>`

### Empfohlen
- `PB_ADMIN_EMAIL` = `admin@germanlion67.de`

### Empfohlen (damit Web-Frontend direkt weiß, wo die API ist)
- `POCKETBASE_URL` = `https://api.germanlion67.de`

### Empfohlen (CORS für Browser absichern; Mobile braucht das nicht)
Wenn du das Web später unter `https://lager.germanlion67.de` nutzen willst:
- `CORS_ALLOWED_ORIGINS` = `https://lager.germanlion67.de`

Wenn du *noch kein* Web unter Domain hast und nur testen willst:
- `CORS_ALLOWED_ORIGINS` = `*` (nicht ideal für Produktion, aber ok für Tests)

> Hinweis: In deinem aktuellen Stack sind `PB_DATA_DIR`, `PB_MIGRATIONS_DIR`, `PB_DEV_MODE` bereits gesetzt/vernünftig.  
> `PB_PORT`/`WEB_PORT` musst du nur setzen, wenn du Ports ändern willst.

---

## ✅ First install ready (optional): ersten App-User automatisch anlegen

Wenn du **bei der Erstinstallation** direkt einen Login-User für die App haben willst
(Collection `users`), setze zusätzlich:

- `PB_TEST_USER_ENABLED` = `1`
- `PB_TEST_USER_EMAIL` = `user@lager.app`
- `PB_TEST_USER_PASSWORD` = `<PASSWORT (mind. 8 Zeichen)>`

Optional (empfohlen für “idempotent” Setup / Passwort später ändern ohne Volume-Reset):
- `PB_TEST_USER_UPSERT` = `1`

> Hinweis: Der PocketBase **Superuser** (`PB_ADMIN_*`) ist **nicht** automatisch ein App-User.  
> Die App authentifiziert sich gegen die Collection `users`.

### ⚠️ Wichtig: Sonderzeichen in Passwörtern (Portainer / Compose)
Einige Zeichen werden bei Environment-Variablen in Docker/Portainer/Compose leicht “falsch” interpretiert:
- Besonders **`$`** (wird oft als Variable/Substitution interpretiert)
- manchmal auch **`&`** (je nach UI/Parser)

Empfehlung:
- Verwende für `PB_TEST_USER_PASSWORD` (und auch `PB_ADMIN_PASSWORD`) Passwörter **ohne `$`**,
  oder escapen den Wert korrekt (siehe `stack.env` Hinweis unten).

---

## Alternative zu “Environment variables” direkt eintippen: stack.env / Upload

Du kannst die Variablen statt im UI einzeln einzutippen auch als Datei pflegen:

- **Variante A:** `stack.env` (oder `.env`) lokal anlegen und in Portainer beim Stack als *Environment file* verwenden (falls in deiner Portainer-Version verfügbar).
- **Variante B:** Eine ENV-Datei in Portainer hochladen/importieren (falls verfügbar) und dem Stack zuweisen.

Beispiel `stack.env` (minimal):

```env
PB_ADMIN_EMAIL=admin@germanlion67.de
PB_ADMIN_PASSWORD=...
POCKETBASE_URL=https://api.germanlion67.de
CORS_ALLOWED_ORIGINS=https://lager.germanlion67.de

PB_TEST_USER_ENABLED=1
PB_TEST_USER_EMAIL=user@lager.app
PB_TEST_USER_PASSWORD=...
PB_TEST_USER_UPSERT=1
```

> Tipp (Compose): Wenn du unbedingt ein `$` im Passwort brauchst, muss es je nach Compose-Parsing
> oft als `$$` geschrieben werden (z. B. `pa$$word`), sonst wird es als Variable interpretiert.

---

## 4) Stack deployen / neu starten

In Portainer:
- Stack **Update the stack** (oder Redeploy)
- Warten bis beide Services **healthy** sind (`pocketbase`, `app`)

---

## 4a) Verifiziertes Startverhalten

Der Portainer-Stack-Betrieb ist für beide Szenarien verifiziert:

### Erststart (frisches `/pb_data`-Volume)
- Collections, Superuser und optionaler Test-User werden **automatisch angelegt**.
- Die Marker-Dateien werden beim ersten erfolgreichen Durchlauf geschrieben:
  - `/pb_data/.superuser_initialized`
  - `/pb_data/.testuser_initialized`
- PocketBase gibt beim Start ggf. einen „Create your first superuser"-Dashboard-Link aus –
  das ist **erwartetes Verhalten**, da das Init-Script den Superuser kurz danach automatisch erstellt.

### Normaler Folgestart
- Das Init-Script verhält sich **idempotent**: Es prüft, was bereits existiert, und überspringt
  bereits erledigte Schritte (erkennbar an den Marker-Dateien).
- Mit `PB_FORCE_SUPERUSER_UPSERT=1` wird der Superuser bei jedem Start neu gesetzt
  (nützlich nach Passwortänderung).
- Mit `PB_TEST_USER_UPSERT=1` wird der Test-User bei jedem Start aktualisiert
  (Passwort + `verified=true`).

### Schnell-Verifikation (Health-Check)

```bash
curl http://127.0.0.1:8080/api/health
# Erwartete Antwort (HTTP 200):
# {"message":"API is healthy."}
```

---

## 4b) Cold-Start-Verifikation (Neuinstallation simulieren)

Damit lässt sich ein Erststart sicher testen, **ohne** die Produktionsdaten dauerhaft zu löschen:

> ⚠️ **Achtung:** Der folgende Schritt löscht **alle PocketBase-Daten** (Collections, User, Attachments).
> Nur auf Test-/Dev-Systemen oder nach einem Backup durchführen!

1. Stack in Portainer **stoppen**.
2. Nur das PocketBase-Daten-Volume entfernen:
   ```bash
   docker volume rm <stack-name>_pb_data
   # z. B.: docker volume rm lager_app_pb_data
   ```
3. Stack in Portainer **neu deployen**.
4. Logs des `pocketbase`-Containers prüfen – erwartet:
   - Keine `[SKIP]`-Zeilen für Migrationen (alles neu)
   - `Successfully saved superuser ...`
   - `✅ Test user created` (falls `PB_TEST_USER_ENABLED=1`)
5. Health-Check:
   ```bash
   curl http://127.0.0.1:8080/api/health
   # → HTTP 200, {"message":"API is healthy."}
   ```

---

## 4c) Fehlerbehebung: Alpine/BusyBox `sed`-Regex-Inkompatibilität

Im Init-Script wird `sed` auf Alpine Linux (BusyBox) verwendet. BusyBox `sed` unterstützt
**keine ERE-Quantoren mit `{}`** in Basis-Regex-Ausdrücken ohne `-E`-Flag.

**Symptom:** Fehlermeldung in den Container-Logs:
```
sed: bad regex '...': Invalid contents of {}
```

**Lösung:** BusyBox-kompatible Muster verwenden (z. B. `[0-9][0-9]*` statt `[0-9]{1,}`)
oder auf `jq` wechseln, das im Container-Image verfügbar ist.

---

## 5) Nginx Proxy Manager (läuft auf anderem Rechner): Proxy Host für die API (Pflicht)

NPM → **Hosts → Proxy Hosts → Add Proxy Host**

### Details
- **Domain Names:** `api.germanlion67.de`
- **Scheme:** `http`
- **Forward Hostname / IP:** `<DEINE_SERVER_IP>`  ✅ (IP vom Portainer/Docker-Server)
- **Forward Port:** `8080`
- **Block Common Exploits:** ✅ an
- **Websockets Support:** optional ✅

### SSL
- **Request a new SSL Certificate:** ✅
- **Force SSL:** ✅
- **HTTP/2 Support:** ✅
- **Email:** deine E-Mail
- **Agree to Terms:** ✅

Speichern.

### Test (von deinem PC/Handy)
Öffne:

- `https://api.germanlion67.de/api/health`

Wenn das geht, ist Mobile-Konnektivität grundsätzlich da.


Datenbankanmeldung mit SuperUser:

- `https://api.germanlion67.de/_/`

---

## 6) Mobile App: Server-URL setzen (Pflicht)

In der Mobile/Desktop App beim Setup-Screen oder in den Einstellungen:

- **PocketBase Server URL:** `https://api.germanlion67.de`

Danach sollte der Verbindungstest grün sein (sofern im Code aktiv).

---

## 7) Optional: Web-Frontend über Domain (empfohlen)

### DNS
A-Record:
- `lager.germanlion67.de` → `<DEINE_SERVER_IP>`

### NPM Proxy Host (Frontend)
NPM → Add Proxy Host:

**Details**
- **Domain Names:** `lager.germanlion67.de`
- **Scheme:** `http`
- **Forward Hostname / IP:** `<DEINE_SERVER_IP>`
- **Forward Port:** `8081`
- **Block Common Exploits:** ✅

**SSL**
- Let's Encrypt + Force SSL ✅

### Dann CORS richtig setzen (Portainer Stack ENV)
- `CORS_ALLOWED_ORIGINS=https://lager.germanlion67.de`

Stack neu deployen / Container neu starten.

---

## 8) Häufige Probleme & Fixes

### A) NPM zeigt `502 Bad Gateway`
Ursachen:
- `<DEINE_SERVER_IP>:8080` von NPM-Rechner aus nicht erreichbar (Firewall/Router)
- PocketBase-Container down / nicht healthy
- Falscher Port

Check (auf dem NPM-Rechner):
```bash
curl -v http://<DEINE_SERVER_IP>:8080/api/health
```

### B) Zertifikat lässt sich nicht erstellen
Ursachen:
- DNS zeigt nicht auf NPM-Rechner (Ports 80/443)
- Port 80 ist nicht erreichbar von außen

### C) Mobile geht, Web geht nicht (CORS)
Ursache:
- `CORS_ALLOWED_ORIGINS` nicht korrekt (muss exakt die Web-Domain sein, ohne Slash)
Beispiel korrekt:
- `https://lager.germanlion67.de`

---

## Empfehlung (Hardening, später)
Dein aktueller Stack published `8080/8081` öffentlich. Das funktioniert, aber „gehärtet“ ist besser:

- PocketBase + Frontend nur intern (`expose:` statt `ports:`)
- Nur NPM öffentlich (80/443)

Im Repository ist dafür bereits ein „Portainer Stack (Produktion)“ Beispiel in `DEPLOYMENT.md`.