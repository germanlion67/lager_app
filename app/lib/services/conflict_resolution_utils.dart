import '../models/artikel_model.dart';

/// Liefert eine belastbare Remote-Baseline für die Konfliktauflösung
/// `useRemote`.
///
/// Zulässige Quellen:
/// 1. `etag`
/// 2. `lastSyncedEtag`
///
/// Nicht zulässig sind semantisch ungeeignete Ersatzwerte wie `remotePath`
/// oder ein leerer String.
///
/// Wirft [StateError], wenn keine belastbare Baseline vorhanden ist.
String requireRemoteBaselineEtag(Artikel remoteVersion) {
  final etag = remoteVersion.etag?.trim();
  if (etag != null && etag.isNotEmpty) {
    return etag;
  }

  final lastSyncedEtag = remoteVersion.lastSyncedEtag?.trim();
  if (lastSyncedEtag != null && lastSyncedEtag.isNotEmpty) {
    return lastSyncedEtag;
  }

  throw StateError(
    'Cannot apply useRemote without a valid remote etag baseline '
    'for artikel ${remoteVersion.uuid}',
  );
}