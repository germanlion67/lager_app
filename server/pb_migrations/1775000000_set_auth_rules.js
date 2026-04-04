/// Migration: API-Regeln auf Authentifizierung setzen
/// Nur eingeloggte User können auf artikel und attachments zugreifen.
///
/// Wichtig:
/// - Diese Migration muss NACH dem Anlegen der Collections laufen.
/// - Sie ist defensiv: wenn die Collection (noch) nicht existiert, wird sie übersprungen,
///   damit ein frisches Setup nicht crasht.

migrate(
  // UP — Regeln verschärfen
  (app) => {
    const collections = ["artikel", "attachments"];
    const authRule = '@request.auth.id != ""';

    for (const name of collections) {
      let collection = null;

      try {
        collection = app.findCollectionByNameOrId(name);
      } catch (e) {
        // PocketBase kann hier intern "sql: no rows..." werfen
        collection = null;
      }

      if (!collection) {
        console.log(`⚠️  Collection nicht gefunden (skip): ${name}`);
        continue;
      }

      collection.listRule   = authRule;
      collection.viewRule   = authRule;
      collection.createRule = authRule;
      collection.updateRule = authRule;
      collection.deleteRule = authRule;

      app.save(collection);
      console.log(`✅ Auth-Regeln gesetzt für: ${name}`);
    }
  },

  // DOWN — Regeln auf offen zurücksetzen (Rollback)
  (app) => {
    const collections = ["artikel", "attachments"];

    for (const name of collections) {
      let collection = null;

      try {
        collection = app.findCollectionByNameOrId(name);
      } catch (e) {
        collection = null;
      }

      if (!collection) {
        console.log(`⚠️  Collection nicht gefunden (skip): ${name}`);
        continue;
      }

      collection.listRule   = "";
      collection.viewRule   = "";
      collection.createRule = "";
      collection.updateRule = "";
      collection.deleteRule = "";

      app.save(collection);
      console.log(`↩️  Regeln auf offen gesetzt für: ${name}`);
    }
  }
);