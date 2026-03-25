/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": "@request.auth.id != ''",
    "deleteRule": "@request.auth.id != ''",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210257",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": "^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text"
      },

      // ── Relation zu artikel ──────────────────────────────────────
      {
        "cascadeDelete": true,
        "collectionId": "pbc_895755225",
        "hidden": false,
        "id": "relation1234560001",
        "maxSelect": 1,
        "minSelect": 1,
        "name": "artikel_id",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },

      // ── Datei ────────────────────────────────────────────────────
      {
        "hidden": false,
        "id": "file1962578386",
        "maxSelect": 1,
        "maxSize": 5242880,
        "mimeTypes": [
          "image/png",
          "image/jpeg",
          "image/gif",
          "image/tiff",
          "image/bmp",
          "image/webp",
          "application/pdf",
          "application/msword",
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          "application/vnd.ms-excel",
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          "text/plain"
        ],
        "name": "datei",
        "presentable": false,
        "protected": false,
        "required": true,
        "system": false,
        "thumbs": [],
        "type": "file"
      },

      // ── Metadaten ────────────────────────────────────────────────
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560002",
        "max": 0,
        "min": 0,
        "name": "dateiname",
        "pattern": "",
        "presentable": true,
        "primaryKey": false,
        "required": true,
        "system": false,
        "type": "text"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560003",
        "max": 0,
        "min": 0,
        "name": "mime_type",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "number1234560004",
        "max": null,
        "min": 0,
        "name": "dateigroesse",
        "onlyInt": true,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560005",
        "max": 0,
        "min": 0,
        "name": "beschreibung",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },

      // ── Sync-Felder (identisch zu artikel) ───────────────────────
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560006",
        "max": 0,
        "min": 0,
        "name": "uuid",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": true,
        "system": false,
        "type": "text"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560007",
        "max": 0,
        "min": 0,
        "name": "etag",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text1234560008",
        "max": 0,
        "min": 0,
        "name": "device_id",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "bool1234560009",
        "name": "deleted",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "bool"
      },
      {
        "hidden": false,
        "id": "number1234560010",
        "max": null,
        "min": null,
        "name": "updated_at",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },

      // ── Auto-Timestamps ──────────────────────────────────────────
      {
        "hidden": false,
        "id": "autodate1234560011",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false,
        "type": "autodate"
      },
      {
        "hidden": false,
        "id": "autodate1234560012",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "presentable": false,
        "system": false,
        "type": "autodate"
      }
    ],
    "id": "pbc_attachments001",
    "indexes": [
      "CREATE INDEX idx_attachments_artikel_id ON attachments (artikel_id)",
      "CREATE INDEX idx_attachments_uuid ON attachments (uuid)",
      "CREATE INDEX idx_attachments_deleted ON attachments (deleted)"
    ],
    "listRule": "@request.auth.id != ''",
    "name": "attachments",
    "system": false,
    "type": "base",
    "updateRule": "@request.auth.id != ''",
    "viewRule": "@request.auth.id != ''"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_attachments001");

  return app.delete(collection);
});