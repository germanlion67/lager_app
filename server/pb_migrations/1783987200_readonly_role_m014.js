/// <reference path="../pb_data/types.d.ts" />
//
// Migration: M-014 — Readonly-User-Rolle
//
// Schritt 1: role-Feld (Text, optional) zur users-Collection hinzufügen.
//            Mögliche Werte: "" / "user" → Vollzugriff | "readonly" → nur Lesen
//
// Schritt 2: createRule / updateRule / deleteRule für artikel + attachments
//            anpassen — readonly-User dürfen nicht schreiben.
//
//            Neu: @request.auth.id != "" && @request.auth.record.role != "readonly"

migrate(
  // UP
  (app) => {
    // ── Schritt 1: role-Feld zu users hinzufügen ──────────────────────────
    let users = null;
    try {
      users = app.findCollectionByNameOrId("users");
    } catch (_) {
      console.log("⚠️  users-Collection nicht gefunden — überspringe role-Feld");
    }

    if (users) {
      const hasRole = users.fields.some((f) => f.name === "role");
      if (!hasRole) {
        users.fields.add(
          new Field({
            hidden: false,
            id: "text_role_m014",
            max: 50,
            min: 0,
            name: "role",
            pattern: "",
            presentable: false,
            primaryKey: false,
            required: false,
            system: false,
            type: "text",
          })
        );
        app.save(users);
        console.log("✅ role-Feld zu users hinzugefügt");
      } else {
        console.log("ℹ️  role-Feld bereits vorhanden — überspringe");
      }
    }

    // ── Schritt 2: Schreibregeln für artikel + attachments anpassen ───────
    const readRule =
      '@request.auth.id != ""';
    const writeRule =
      '@request.auth.id != "" && @request.auth.record.role != "readonly"';
    const collections = ["artikel", "attachments"];

    for (const name of collections) {
      let col = null;
      try {
        col = app.findCollectionByNameOrId(name);
      } catch (_) {
        col = null;
      }

      if (!col) {
        console.log(`⚠️  Collection nicht gefunden (skip): ${name}`);
        continue;
      }

      col.listRule   = readRule;
      col.viewRule   = readRule;
      col.createRule = writeRule;
      col.updateRule = writeRule;
      col.deleteRule = writeRule;

      app.save(col);
      console.log(`✅ Readonly-Schreibregeln gesetzt für: ${name}`);
    }
  },

  // DOWN — Rollback: Regeln auf auth-only, role-Feld entfernen
  (app) => {
    const authRule = '@request.auth.id != ""';

    // Schreibregeln zurücksetzen
    const collections = ["artikel", "attachments"];
    for (const name of collections) {
      let col = null;
      try {
        col = app.findCollectionByNameOrId(name);
      } catch (_) {
        col = null;
      }

      if (!col) {
        console.log(`⚠️  Collection nicht gefunden (skip): ${name}`);
        continue;
      }

      col.listRule   = authRule;
      col.viewRule   = authRule;
      col.createRule = authRule;
      col.updateRule = authRule;
      col.deleteRule = authRule;

      app.save(col);
      console.log(`✅ Regeln zurückgesetzt für: ${name}`);
    }

    // role-Feld aus users entfernen
    let users = null;
    try {
      users = app.findCollectionByNameOrId("users");
    } catch (_) {
      console.log("⚠️  users-Collection nicht gefunden — überspringe");
    }

    if (users) {
      const hasRole = users.fields.some((f) => f.name === "role");
      if (hasRole) {
        users.fields.removeById("text_role_m014");
        app.save(users);
        console.log("✅ role-Feld aus users entfernt");
      }
    }
  }
);
