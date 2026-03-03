# Lager App

A Flutter application for managing electronic parts and components in a local inventory. The app lets you create, edit, search, and organize items (name, description, storage location/bin, quantity, and an optional image). It supports importing/exporting item data (CSV/JSON), syncing with Nextcloud (WebDAV), QR-code scanning, and built-in logging for troubleshooting.

- **Status:** WIP
- **Version:** v0.1.0
- **License:** MIT
- **Maintainer:** @germanlion67

---

## Overview

**Problem / Use case:** Keeping track of electronics parts in a workshop, lab, or makerspace can quickly become messy.

**Target audience:** Hobbyists, makers, small labs, and anyone who wants an offline-first inventory app for parts.

**What it does:** Provides a simple UI to manage items, persist them locally (SQLite), and optionally sync the inventory via Nextcloud.

**What it is not:** This is not a full ERP system and does not try to replace professional warehouse management solutions.

### Core functionality

- Item list with fast search
- Create, edit, and delete items
- Quantity management
- Attach images from file system or camera
- Import/Export inventory data (CSV/JSON)
- Optional Nextcloud synchronization (WebDAV)
- QR code scan to open/identify items
- Error and event logging

### Benefits

- **Offline-first:** Works without a backend server.
- **Portable:** Runs on mobile and desktop (Flutter).
- **Data ownership:** Your inventory stays local; sync is optional.

### Important notes / risks

- **Backups:** Export your data regularly (CSV/JSON) before experimenting with sync.
- **Sync conflicts:** When using Nextcloud, conflicting edits across devices may require manual resolution.
- **Costs/Performance:** Large image libraries and very big inventories can increase storage usage and slow down searches on older devices.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Local](#local)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Quick start](#quick-start)
  - [Command line](#command-line)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Inventory management:** Create, edit, delete, and search items.
- **Images:** Add images via file picker or camera.
- **Import/Export:** CSV/JSON import and export.
- **Nextcloud sync:** Synchronize inventory data via WebDAV.
- **QR scan:** Scan QR codes to find/open items.
- **Logging:** Built-in error and event logging.

---

## Requirements

- **Flutter SDK:** (see `.metadata` / project configuration)
- **Platforms:** Android, iOS, Windows, macOS, Linux, Web (depending on your Flutter setup)

---

## Installation

### Local

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
flutter pub get
flutter run
```

---

## Configuration

The app is primarily configured through the UI. Depending on the feature set, you may need to configure:

- Nextcloud/WebDAV URL
- Nextcloud credentials (username/app password)

---

## Usage

### Quick start

1. Start the app.
2. Create your first item (name, location/bin, quantity).
3. Optionally add an image.
4. Use search and/or QR scan to find items.
5. (Optional) Enable Nextcloud sync in settings.

### Command line

```bash
# Run the app
flutter run

# Run tests
flutter test

# Analyze
flutter analyze
```

---

## Troubleshooting

- Run with more logging/diagnostics:
  - `flutter run -v`
- If sync fails:
  - Verify Nextcloud URL and credentials
  - Check network connectivity

---

## Development

### Project structure

```text
lib/
  helpers/
  models/
  screens/
  services/
  widgets/
```

### Tests

```bash
flutter test
```

---

## Contributing

- Issues and feature requests: https://github.com/germanlion67/lager_app/issues
- Pull requests are welcome.

---

## License

This project is licensed under the **MIT** License.
See [LICENSE](LICENSE).
