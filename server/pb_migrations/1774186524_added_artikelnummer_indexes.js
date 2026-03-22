/// <reference path="../pb_data/types.d.ts" />

// Migration: M-007 - Add artikelnummer field with unique constraint and indexes
//
// Ziele:
// - Artikelnummer-Feld hinzufügen (eindeutig, auto-increment)
// - Unique Constraint für Datenintegrität
// - Indexes für Performance (bis 10000 Artikel)
// - Volltextsuche-Unterstützung für name, beschreibung, artikelnummer

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("pbc_895755225");

    if (!collection) {
      throw new Error('Collection "artikel" nicht gefunden!');
    }

    // Idempotent: skip if field already exists.
    const hasArtikelnummer = collection.fields.some((f) => f.name === "artikelnummer");
    if (!hasArtikelnummer) {
      // IMPORTANT: PocketBase expects a core.Field object.
      // Do NOT use addAt(...) or add(index, ...) because not all PocketBase versions
      // support it in JS migrations and it can cause:
      // "could not convert [object Object] to core.Field"
      collection.fields.add(
        new Field({
          autogeneratePattern: "",
          hidden: false,
          id: "number_artikelnummer",
          max: 99999, // Bis 10000 Artikel (mit Puffer)
          min: 1,
          name: "artikelnummer",
          onlyInt: true,
          presentable: true, // Wird als Anzeige-Name verwendet
          required: false, // Bestehende Artikel haben keine Nummer
          system: false,
          type: "number",
        }),
      );
    }

    // Indexes hinzufügen (idempotent)
    const addIndexIfMissing = (sql) => {
      if (!collection.indexes.includes(sql)) {
        collection.indexes.push(sql);
      }
    };

    // 1. Unique Index für Artikelnummer (Datenintegrität)
    addIndexIfMissing(
      "CREATE UNIQUE INDEX `idx_unique_artikelnummer` ON `artikel` (`artikelnummer`) WHERE `artikelnummer` IS NOT NULL AND `deleted` = FALSE",
    );

    // 2. Performance-Index für Volltextsuche
    // SQLite FTS (Full-Text Search) via name + beschreibung
    addIndexIfMissing(
      "CREATE INDEX `idx_search_name` ON `artikel` (`name`) WHERE `deleted` = FALSE",
    );

    addIndexIfMissing(
      "CREATE INDEX `idx_search_beschreibung` ON `artikel` (`beschreibung`) WHERE `deleted` = FALSE",
    );

    // 3. Composite Index für häufige Abfragen (deleted + updated_at)
    // Wird für Sync-Abfragen verwendet
    addIndexIfMissing(
      "CREATE INDEX `idx_sync_deleted_updated` ON `artikel` (`deleted`, `updated_at`)",
    );

    // 4. Index für UUID-basierte Lookups (häufig beim Sync)
    addIndexIfMissing("CREATE INDEX `idx_uuid` ON `artikel` (`uuid`)");

    return app.save(collection);
  },
  (app) => {
    // Rollback: Feld und Indexes entfernen
    const collection = app.findCollectionByNameOrId("pbc_895755225");

    if (!collection) {
      throw new Error('Collection "artikel" nicht gefunden!');
    }

    // Artikelnummer-Feld entfernen (falls vorhanden)
    try {
      collection.fields.removeById("number_artikelnummer");
    } catch (_) {
      // ignore
    }

    // Indexes entfernen (SQLite DROP INDEX)
    collection.indexes = collection.indexes.filter(
      (idx) =>
        !idx.includes("idx_unique_artikelnummer") &&
        !idx.includes("idx_search_name") &&
        !idx.includes("idx_search_beschreibung") &&
        !idx.includes("idx_sync_deleted_updated") &&
        !idx.includes("idx_uuid"),
    );

    return app.save(collection);
  },
);
