# 🐳 Portainer Prod Setup (NPM läuft auf anderem Rechner)

Stand: 2026-04-03  
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

## 4) Stack deployen / neu starten

In Portainer:
- Stack **Update the stack** (oder Redeploy)
- Warten bis beide Services **healthy** sind (`pocketbase`, `app`)

Optional testen auf dem Server selbst:

```bash
curl -sS http://127.0.0.1:8080/api/health
```

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
