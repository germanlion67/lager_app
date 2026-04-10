# Android Release‑Keystore (GitHub Actions) – Anleitung

Diese Anleitung richtet einen **stabilen Android Release‑Keystore** ein, damit eure APK/AAB **updates über eine bestehende Installation** zulässt (kein Deinstallieren mehr nötig), und der Release‑Workflow in GitHub Actions sauber signiert.

## Voraussetzungen
- JDK installiert (für `keytool`)
- Zugriff auf Repo‑Settings (Secrets)
- Euer Workflow baut bereits `flutter build apk --release` / `flutter build appbundle --release` (bei euch: `.github/workflows/release.yml`)

---

## 1) Release‑Keystore lokal erzeugen (einmalig)

Im Terminal (macOS/Linux/Windows mit JDK):

```bash
keytool -genkeypair -v \
  -keystore lager_app-release.jks \
  -alias lager_app \
  -keyalg RSA -keysize 2048 -validity 10000
```

Merke dir:
- `storePassword` (Keystore-Passwort)
- `keyPassword` (Key-Passwort)
- `keyAlias` (hier: `lager_app`)

**Wichtig:** Den Keystore niemals verlieren. Ohne den gleichen Keystore sind spätere Updates nicht möglich.

---

## 2) Keystore in Base64 umwandeln (für GitHub Secret)

### macOS / Linux
```bash
base64 -w 0 lager_app-release.jks > keystore.b64
```

### Windows PowerShell
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("lager_app-release.jks")) | Set-Content -NoNewline keystore.b64
```

Öffne `keystore.b64` und kopiere den kompletten Inhalt (eine lange Zeile).

---

## 3) GitHub Actions Secrets anlegen

Repo → **Settings → Secrets and variables → Actions → New repository secret**

Lege diese Secrets an:

- `ANDROID_KEYSTORE_BASE64` = Inhalt aus `keystore.b64`
- `ANDROID_KEYSTORE_PASSWORD` = storePassword
- `ANDROID_KEY_PASSWORD` = keyPassword
- `ANDROID_KEY_ALIAS` = `lager_app`

---

## 4) Workflow erweitern: Keystore dekodieren + `key.properties` erzeugen

In `.github/workflows/release.yml` im Job **`build-android`** füge **nach** “Checkout” / “Setup …” und **vor** “Build APK” diesen Step ein:

```yaml
      - name: Decode Android keystore & create key.properties
        working-directory: ./app/android
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > app-release.jks

          cat > key.properties <<'EOF'
          storeFile=app-release.jks
          storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          EOF
```

Ergebnis im Runner:
- `app/android/app-release.jks`
- `app/android/key.properties`

Beides wird **nur zur Build-Zeit** erzeugt und nicht ins Repo geschrieben.

---

## 5) Android Gradle so ändern, dass Release mit dem Keystore signiert wird

Aktuell ist in `app/android/app/build.gradle.kts` Release noch auf Debug-Signing gesetzt:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Das muss ersetzt werden durch Laden von `key.properties` + Release SigningConfig.

### Beispiel-Implementierung (Kotlin DSL)

Füge in `app/android/app/build.gradle.kts` folgende Logik **innerhalb** von `android { ... }` hinzu (oder passend integrieren):

```kotlin
import java.util.Properties

android {
    // ...

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

**Hinweise:**
- `rootProject.file("key.properties")` passt, weil `key.properties` unter `app/android/key.properties` liegt und das `android`-Projekt die rootProject-Ebene `app/android` hat.
- Wenn du auch lokal Release bauen willst, kannst du lokal ebenfalls eine `key.properties` anlegen (aber niemals committen).

---

## 6) VersionCode sicher erhöhen (sonst kein Update möglich)

Android Updates gehen nur, wenn der `versionCode` steigt. Bei Flutter kommt der i.d.R. aus `pubspec.yaml` über:

```yaml
version: 0.8.1+2
```

- `0.8.1` = versionName
- `+2` = build number → wird zu `versionCode`

**Regel:** Bei jedem Release die Zahl nach `+` erhöhen (`+3`, `+4`, …).

---

## 7) Sicherheits- und Git-Regeln

### Nicht committen
- Keystore: `*.jks` / `*.keystore`
- `key.properties`

Empfohlen in `.gitignore` (falls nicht vorhanden):

```gitignore
**/*.jks
**/*.keystore
**/key.properties
```

### Secrets schützen
- Keystore-Base64 und Passwörter gehören nur in GitHub Secrets.
- Bei Keystore-Wechsel: bestehende Installationen können nicht mehr aktualisiert werden.

---

## 8) Test (Smoke Test)
1. Einen Release über den Workflow auslösen.
2. APK installieren.
3. Neue Version bauen (mit höherem `+build`).
4. APK erneut installieren → sollte jetzt als **Update** durchlaufen.