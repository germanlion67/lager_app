/// <reference path="../pb_data/types.d.ts" />
//
// Migration: P-008 — PocketBase Thumbnail-Konfiguration
//
// Fügt thumbs ["60x60", "400x400", "1200x1200"] zum bild-Feld (file1962578385)
// der artikel-Collection hinzu.
//
// Verwendung:
//   60x60    → Listenansicht  (pbThumbGroesse)
//   400x400  → Detailansicht  (pbThumbGroesseDetail)
//   1200x1200 → Vollbildviewer (pbThumbGroesseVollbild)
//
// Hinweis: Bestehende Bilder erhalten neue Thumbnails erst beim nächsten
// Upload. Neue Uploads ab dieser Migration sind sofort korrekt.

const THUMBS = ["60x60", "400x400", "1200x1200"];

migrate(
  // UP
  (app) => {
    let collection = null;
    try {
      collection = app.findCollectionByNameOrId("artikel");
    } catch (_) {
      console.log("⚠️  artikel-Collection nicht gefunden — überspringe");
      return;
    }

    const bildField = collection.fields.getById("file1962578385");
    if (!bildField) {
      console.log("⚠️  bild-Feld (file1962578385) nicht gefunden — überspringe");
      return;
    }

    if (JSON.stringify(bildField.thumbs) === JSON.stringify(THUMBS)) {
      console.log("ℹ️  Thumbs bereits konfiguriert — überspringe");
      return;
    }

    bildField.thumbs = THUMBS;
    app.save(collection);
    console.log("✅  artikel.bild thumbs gesetzt: " + THUMBS.join(", "));
  },

  // DOWN
  (app) => {
    let collection = null;
    try {
      collection = app.findCollectionByNameOrId("artikel");
    } catch (_) {
      return;
    }

    const bildField = collection.fields.getById("file1962578385");
    if (bildField) {
      bildField.thumbs = [];
      app.save(collection);
      console.log("↩️  artikel.bild thumbs zurückgesetzt auf []");
    }
  }
);
