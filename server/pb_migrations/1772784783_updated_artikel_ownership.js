/// <reference path="../pb_data/types.d.ts" />
//
// Migration: Add owner/sharedWith relations to artikel and update API rules.
//
// Rules depend on PB_DEV_MODE environment variable:
//   PB_DEV_MODE=1 (default): open rules — no auth required (dev/quickstart)
//   PB_DEV_MODE=0           : secure rules — owner/writer enforcement (prod)
//
migrate((app) => {
  const devMode = $os.getenv("PB_DEV_MODE") !== "0";

  const artikelCollection = app.findCollectionByNameOrId("pbc_895755225");

  // Get users collection ID for relation fields
  const usersCollection = app.findCollectionByNameOrId("users");
  const usersId = usersCollection.id;

  // Add owner relation field if not already present.
  // Name-based check is intentional: we only want to avoid adding a
  // duplicate field on repeated runs. If the field already exists with
  // different properties, manual admin UI intervention is required.
  const hasOwner = artikelCollection.fields.some(f => f.name === "owner");
  if (!hasOwner) {
    artikelCollection.fields.add(new Field({
      "cascadeDelete": false,
      "collectionId": usersId,
      "hidden": false,
      "id": "relation_owner_field",
      "maxSelect": 1,
      "minSelect": 0,
      "name": "owner",
      "presentable": false,
      "required": false,
      "system": false,
      "type": "relation"
    }));
  }

  // Add sharedWith relation field if not already present.
  // Same name-based idempotency strategy as owner above.
  const hasSharedWith = artikelCollection.fields.some(f => f.name === "sharedWith");
  if (!hasSharedWith) {
    artikelCollection.fields.add(new Field({
      "cascadeDelete": false,
      "collectionId": usersId,
      "hidden": false,
      "id": "relation_shared_field",
      "maxSelect": 99,
      "minSelect": 0,
      "name": "sharedWith",
      "presentable": false,
      "required": false,
      "system": false,
      "type": "relation"
    }));
  }

  // Set rules based on PB_DEV_MODE
  if (devMode) {
    // Dev/Test: open access — no auth required
    // Fixes "Failed to create record" 400 errors for unauthenticated users
    artikelCollection.listRule   = "";
    artikelCollection.viewRule   = "";
    artikelCollection.createRule = "";
    artikelCollection.updateRule = "";
    artikelCollection.deleteRule = "";
  } else {
    // Prod: secure rules
    // list/view: authenticated AND (owner OR sharedWith)
    const ownerOrShared =
      "@request.auth.id != '' && " +
      "(@record.owner = @request.auth.id || " +
      "@record.sharedWith.id ?= @request.auth.id)";

    // create: authenticated writer; enforce owner = self
    const createRule =
      "@request.auth.id != '' && " +
      "@request.auth.role = 'writer' && " +
      "@request.data.owner = @request.auth.id";

    // update/delete: authenticated writer AND owner = self
    const ownerWriterRule =
      "@request.auth.id != '' && " +
      "@request.auth.role = 'writer' && " +
      "@record.owner = @request.auth.id";

    artikelCollection.listRule   = ownerOrShared;
    artikelCollection.viewRule   = ownerOrShared;
    artikelCollection.createRule = createRule;
    artikelCollection.updateRule = ownerWriterRule;
    artikelCollection.deleteRule = ownerWriterRule;
  }

  return app.save(artikelCollection);
}, (app) => {
  // Revert: remove owner/sharedWith fields and restore original auth rules
  const artikelCollection = app.findCollectionByNameOrId("pbc_895755225");

  const ownerField = artikelCollection.fields.getByName("owner");
  if (ownerField) {
    artikelCollection.fields.remove(ownerField);
  }

  const sharedWithField = artikelCollection.fields.getByName("sharedWith");
  if (sharedWithField) {
    artikelCollection.fields.remove(sharedWithField);
  }

  // Restore original rules (auth required)
  artikelCollection.listRule   = "@request.auth.id != ''";
  artikelCollection.viewRule   = "@request.auth.id != ''";
  artikelCollection.createRule = "@request.auth.id != ''";
  artikelCollection.updateRule = "@request.auth.id != ''";
  artikelCollection.deleteRule = "@request.auth.id != ''";

  return app.save(artikelCollection);
});
