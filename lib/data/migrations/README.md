# Persistence migrations

`AppDatabase.schemaVersion` starts at **1**. The retained baseline is
`drift_schemas/drift_schema_v1.json`, with generated verification helpers in
`test/generated_migrations/`.

Every future schema change must increment `schemaVersion`, add a non-destructive
`onUpgrade` path, export a new schema JSON file, regenerate the verification
helpers, and add a populated old-version migration test. Production upgrades
must never delete and recreate the shop database.

Commands used for the baseline:

```text
dart run drift_dev schema dump lib/data/app_database.dart drift_schemas
dart run drift_dev schema generate drift_schemas test/generated_migrations
```

## Receipt settings snapshot

`orders.receipt_settings_snapshot` is UTF-8 JSON with an explicit integer
`version`. Version 1 contains `shopName`, `address`, `phone`, and `footer`.
Order reads decode this saved JSON and never join mutable `app_settings`, so a
later shop-settings edit cannot change historical reprint content. A future
shape must add a decoder branch for previous versions before writing the new
version.
