/// Migration: API-Regeln auf Authentifizierung setzen
/// Nur eingeloggte User können auf artikel und attachments zugreifen.

migrate(
  // UP — Regeln verschärfen
  (app) => {
    const collections = ["artikel", "attachments"];
    const authRule = '@request.auth.id != ""';

    for (const name of collections) {
      const collection = app.findCollectionByNameOrId(name);

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
      const collection = app.findCollectionByNameOrId(name);

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