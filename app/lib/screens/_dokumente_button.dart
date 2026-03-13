// lib/screens/_dokumente_button.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/dokumente_utils.dart';
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_webdav_client.dart';
import '../services/nextcloud_connection_service.dart';
import '../services/app_log_service.dart';

// ─────────────────────────────────────────────
// DokumenteButton — Mobile Widget
// ─────────────────────────────────────────────

class DokumenteButton extends StatefulWidget {
  final int? artikelId;

  /// Optionaler Test-Hook: Funktion zum Lesen von Nextcloud-Credentials.
  /// Wenn null, wird NextcloudCredentialsStore().read() verwendet.
  final Future<NextcloudCredentials?> Function()? credentialsReader;

  const DokumenteButton({
    super.key,
    required this.artikelId,
    this.credentialsReader,
  });

  @override
  State<DokumenteButton> createState() => DokumenteButtonState();
}

class DokumenteButtonState extends State<DokumenteButton> {
  int? _count;
  bool _loading = true;
  bool _dirExists = true;

  final NextcloudConnectionService _connectionService =
      NextcloudConnectionService();

  @override
  void initState() {
    super.initState();
    _connectionService.startPeriodicCheck();
    _loadCount();
  }

  // 🔴 FIX 1: dispose() — stopPeriodicCheck damit kein Timer-Leak entsteht
  @override
  void dispose() {
    _connectionService.stopPeriodicCheck();
    super.dispose();
  }

  Future<void> _loadCount() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    final creds = widget.credentialsReader != null
        ? await widget.credentialsReader!()
        : await NextcloudCredentialsStore().read();

    if (!mounted) return;

    if (creds == null || widget.artikelId == null) {
      setState(() {
        _count = null;
        _dirExists = false;
        _loading = false;
      });
      return;
    }

    final config = NextcloudConfig(
      serverBase: creds.server,
      username: creds.user,
      appPassword: creds.appPw,
      baseRemoteFolder: creds.baseFolder,
    );
    final client = NextcloudWebDavClient(config);

    try {
      final files = await client.listFiles(widget.artikelId.toString());

      if (!mounted) return;

      setState(() {
        _count = files.length;
        _dirExists = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _count = null;
        _dirExists = false;
        _loading = false;
      });
    }
  }

  // 🔵 FIX 4: _showDokumenteSheet schlank — Logik in _DokumenteSheet ausgelagert
  void _showDokumenteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DokumenteSheet(
        artikelId: widget.artikelId,
        credentialsReader: widget.credentialsReader,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String countText;
    if (_loading) {
      countText = '(...)';
    } else if (!_dirExists) {
      countText = '(-)';
    } else if (_count == 0) {
      countText = '(0)';
    } else {
      countText = '(${_count ?? '-'})';
    }

    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.folder),
          label: Text('zusätzliche Dokumente $countText'),
          onPressed: _showDokumenteSheet,
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<NextcloudConnectionStatus>(
          valueListenable: _connectionService.connectionStatus,
          builder: (context, status, _) {
            if (status == NextcloudConnectionStatus.online) {
              return const Icon(Icons.cloud_done, color: Colors.green);
            } else if (status == NextcloudConnectionStatus.offline) {
              return const Icon(Icons.cloud_off, color: Colors.red);
            } else {
              return const Icon(Icons.cloud_queue, color: Colors.grey);
            }
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// _DokumenteSheet — Privates StatefulWidget
// 🔵 FIX 4: Aus StatefulBuilder ausgelagert
// ─────────────────────────────────────────────

class _DokumenteSheet extends StatefulWidget {
  final int? artikelId;
  final Future<NextcloudCredentials?> Function()? credentialsReader;

  const _DokumenteSheet({
    required this.artikelId,
    this.credentialsReader,
  });

  @override
  State<_DokumenteSheet> createState() => _DokumenteSheetState();
}

class _DokumenteSheetState extends State<_DokumenteSheet> {
  List<String> _files = [];
  bool _loading = true;

  // 🟡 FIX 2: Dateiname als Key statt Index — korrekt nach Sortierung
  final Map<String, bool> _downloading = {};

  NextcloudConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // messenger vor async-Gap cachen
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final creds = widget.credentialsReader != null
          ? await widget.credentialsReader!()
          : await NextcloudCredentialsStore().read();

      if (!mounted) return;

      if (creds == null || widget.artikelId == null) {
        setState(() {
          _files = [];
          _loading = false;
        });
        unawaited(
          AppLogService().log(
            'Dokumente: keine Credentials oder artikelId, Abbruch',
          ),
        );
        return;
      }

      final cfg = NextcloudConfig(
        serverBase: creds.server,
        username: creds.user,
        appPassword: creds.appPw,
        baseRemoteFolder: creds.baseFolder,
      );
      _currentConfig = cfg;

      final client = NextcloudWebDavClient(cfg);
      final fetched = await client
          .listFiles(widget.artikelId.toString())
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      setState(() => _files = fetched);

      unawaited(
        AppLogService().log(
          'Dokumente: Fetched ${fetched.length} '
          'dokumente für artikel ${widget.artikelId}',
        ),
      );
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _files = [];
          _loading = false;
        });
      }
      unawaited(
        AppLogService().logError('Dokumente: Fehler beim Laden: $e', stack),
      );
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Dokumente: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _downloadAndOpen(String file, int artikelId) async {
    if (_downloading[file] == true) return;

    setState(() => _downloading[file] = true);

    // messenger vor async-Gap cachen
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cfg = _currentConfig;

    unawaited(
      AppLogService().log(
        'Dokumente: Download gestartet für $file (artikel $artikelId)',
      ),
    );

    if (cfg == null) {
      setState(() => _downloading.remove(file));
      unawaited(
        AppLogService().log(
          'Dokumente: Abbruch Download - keine Config',
        ),
      );
      return;
    }

    try {
      final client = NextcloudWebDavClient(cfg);
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$file';

      await client.downloadFile('$artikelId/$file', tempPath);

      unawaited(
        AppLogService().log(
          'Dokumente: Download erfolgreich für $file -> $tempPath',
        ),
      );

      if (!mounted) return;

      final result = await OpenFile.open(tempPath);

      if (!mounted) return;

      if (result.type == ResultType.done) {
        unawaited(
          AppLogService().log('Dokumente: Datei geöffnet: $file'),
        );
        messenger?.showSnackBar(
          SnackBar(content: Text('Datei geöffnet: $file')),
        );
      } else {
        unawaited(
          AppLogService().logError(
            'Dokumente: Datei konnte nicht geöffnet werden: ${result.message}',
            StackTrace.current,
          ),
        );
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Datei konnte nicht geöffnet werden: ${result.message}',
            ),
          ),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      unawaited(
        AppLogService().logError(
          'Dokumente: Fehler beim Download/Öffnen: $e',
          st,
        ),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('Fehler beim Öffnen: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloading.remove(file));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 🟢 FIX 3: context aus build() — korrekt für dieses Widget
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: (v) {
                    if (v == 'name') {
                      setState(() => _files = sortFilesByName(_files));
                    } else if (v == 'type') {
                      setState(
                        () => _files = sortFilesByTypeThenName(_files),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'name',
                      child: Text('Sortiere nach Name'),
                    ),
                    PopupMenuItem(
                      value: 'type',
                      child: Text('Sortiere nach Typ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFiles,
                    child: _files.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text('Keine Dokumente vorhanden.'),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            itemCount: _files.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final file = _files[i];
                              final ext = file.contains('.')
                                  ? file.split('.').last.toLowerCase()
                                  : '';

                              Widget leadingWidget;
                              Widget? subtitleWidget;

                              if ([
                                'jpg',
                                'jpeg',
                                'png',
                                'gif',
                                'bmp',
                                'webp',
                              ].contains(ext)) {
                                final authHeader = _currentConfig != null
                                    ? 'Basic ${base64Encode(
                                        utf8.encode(
                                          '${_currentConfig!.username}'
                                          ':${_currentConfig!.appPassword}',
                                        ),
                                      )}'
                                    : null;

                                leadingWidget = ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 72,
                                    height: 48,
                                    child: _currentConfig != null &&
                                            authHeader != null
                                        ? CachedNetworkImage(
                                            imageUrl: _currentConfig!
                                                .webDavRoot
                                                .resolve(
                                                  '${widget.artikelId}/$file',
                                                )
                                                .toString(),
                                            httpHeaders: {
                                              'Authorization': authHeader,
                                            },
                                            fit: BoxFit.cover,
                                            placeholder: (c, u) => const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            errorWidget: (c, u, e) =>
                                                const Icon(Icons.broken_image),
                                          )
                                        : const Icon(Icons.broken_image),
                                  ),
                                );
                                subtitleWidget = const Text(
                                  'Bilddatei',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                );
                              } else if (ext == 'pdf') {
                                leadingWidget = const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                  size: 36,
                                );
                                subtitleWidget = const Text(
                                  'PDF-Datei',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                );
                              } else if (['doc', 'docx', 'odt'].contains(ext)) {
                                leadingWidget = const Icon(
                                  Icons.description,
                                  color: Colors.green,
                                  size: 36,
                                );
                                subtitleWidget = const Text(
                                  'Textdokument',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                );
                              } else {
                                leadingWidget = const Icon(
                                  Icons.insert_drive_file,
                                  size: 36,
                                );
                                subtitleWidget = null;
                              }

                              // 🟡 FIX 2: file als Key statt i
                              final isDownloading = _downloading[file] == true;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 4,
                                ),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  leading: leadingWidget,
                                  title: Text(
                                    file,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: subtitleWidget,
                                  trailing: isDownloading
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.open_in_new),
                                  onTap: widget.artikelId != null
                                      ? () => _downloadAndOpen(
                                            file,
                                            widget.artikelId!,
                                          )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}