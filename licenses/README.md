# Lizenz-Audit (Initialer Snapshot)

Dieser Ordner verfolgt die Compliance-Arbeit bezüglich Abhängigkeitslizenzen für `lager_app`.

## Dateien

- `DEPENDENCIES_LIST.md`: Die maßgebliche Abhängigkeitsliste, kopiert aus `app/pubspec.lock` (mit Überschrift/Kontext-Wrapper).
- `DEPENDENCIES_LICENSES.md`: Eine Zusammenfassungstabelle mit Paket/Version/Lizenz/Quelle.
- `*-LICENSE.txt`: Lizenzzusammenfassungsdateien pro Paket mit Quell- und Lizenztext-Links.
- `AUDIT_PROGRESS.md`: Ein kurzer Fortschrittstracker für diesen Audit-Durchlauf.
- `AUDIT_COMMIT_NOTE.txt`: Eine Commit-bezogene Notiz für diese initiale Sammlung.

## Nächste Schritte

1. Erweiterung der Abdeckung vom anfänglichen Abhängigkeits-Subset auf alle transitiven Abhängigkeiten.
2. Ersetzen von ausschließlich verlinkten Paket-Einträgen durch eingebettete vollständige Lizenztexte, wo dies für die Distribution erforderlich ist.
3. Überprüfung auf NOTICE/AUTHORS-Verpflichtungen (insbesondere bei Apache-2.0-Abhängigkeiten) und deren Aufnahme in die Release-Artefakte.
