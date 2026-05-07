# Licenses Audit (Initial Snapshot)

This folder tracks dependency license compliance work for `lager_app`.

## Files

- `DEPENDENCIES_LIST.md`: authoritative dependency list copied from `app/pubspec.lock` (with heading/context wrapper).
- `DEPENDENCIES_LICENSES.md`: package/version/license/source summary table.
- `*-LICENSE.txt`: per-package license summary files with source and license-text links.
- `AUDIT_PROGRESS.md`: short progress tracker for this audit pass.
- `AUDIT_COMMIT_NOTE.txt`: commit-scoped note for this initial collection.

## Next Steps

1. Expand coverage from the initial dependency subset to all transitive dependencies.
2. Replace link-only package entries with embedded full license texts where needed for distribution.
3. Check for NOTICE/AUTHORS obligations (especially Apache-2.0 dependencies) and include them in release artifacts.
