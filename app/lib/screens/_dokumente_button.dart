import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/dokumente_utils.dart';
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_webdav_client.dart';
import '../services/nextcloud_connection_service.dart';
import '../services/app_log_service.dart';

class DokumenteButton extends StatefulWidget {
  final int? artikelId;
  /// Optionaler Test-Hook: Funktion zum Lesen von Nextcloud-Credentials.
  /// Wenn null, wird NextcloudCredentialsStore().read() verwendet.
  final Future<NextcloudCredentials?> Function()? credentialsReader;
  const DokumenteButton({super.key, required this.artikelId, this.credentialsReader});

  @override
  State<DokumenteButton> createState() => DokumenteButtonState();
}

class DokumenteButtonState extends State<DokumenteButton> {
  int? _count;
  bool _loading = true;
  bool _dirExists = true;
  late NextcloudConnectionService _connectionService;

  @override
  void initState() {
    super.initState();
    _connectionService = NextcloudConnectionService();
    _loadCount();
  }

  Future<void> _loadCount() async {
    setState(() { _loading = true; });
    final creds = widget.credentialsReader != null ? await widget.credentialsReader!() : await NextcloudCredentialsStore().read();
    if (creds == null || widget.artikelId == null) {
      setState(() { _count = null; _dirExists = false; _loading = false; });
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
      setState(() {
        _count = files.length;
        _dirExists = true;
        _loading = false;
      });
    } catch (e) {
      setState(() { _count = null; _dirExists = false; _loading = false; });
    }
  }

  void _showDokumenteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        List<String> files = [];
        bool loading = true;
        final Map<int, bool> downloading = {};
        NextcloudConfig? currentConfig;
        bool hasScheduledInitialLoad = false;

        return StatefulBuilder(builder: (contextSB, setStateSB) {
          final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(contextSB);

          Future<void> loadFiles() async {
            debugPrint('DokumenteSheet: loadFiles() gestartet für artikel ${widget.artikelId}');
            unawaited(AppLogService().log('Dokumente: loadFiles() gestartet für artikel ${widget.artikelId}'));
            if (!contextSB.mounted) return;
            setStateSB(() { loading = true; });
            try {
              final creds = widget.credentialsReader != null ? await widget.credentialsReader!() : await NextcloudCredentialsStore().read();
              debugPrint('DokumenteSheet: creds geladen: ${creds != null}');
              unawaited(AppLogService().log('Dokumente: creds geladen: ${creds != null} für artikel ${widget.artikelId}'));
              if (creds == null || widget.artikelId == null) {
                if (!contextSB.mounted) return;
                setStateSB(() { files = []; });
                unawaited(AppLogService().log('Dokumente: keine Credentials oder artikelId, Abbruch'));
                return;
              }
              final cfg = NextcloudConfig(
                serverBase: creds.server,
                username: creds.user,
                appPassword: creds.appPw,
                baseRemoteFolder: creds.baseFolder,
              );
              currentConfig = cfg;
              final client = NextcloudWebDavClient(cfg);
              final fetched = await client.listFiles(widget.artikelId.toString()).timeout(const Duration(seconds: 15));
              debugPrint('DokumenteSheet: Fetched ${fetched.length} dokumente for artikel ${widget.artikelId}');
              unawaited(AppLogService().log('Dokumente: Fetched ${fetched.length} dokumente für artikel ${widget.artikelId}'));
              if (!contextSB.mounted) return;
              setStateSB(() { files = fetched; });
            } catch (e, stack) {
              if (contextSB.mounted) {
                setStateSB(() { files = []; });
              }
              unawaited(AppLogService().logError('Dokumente: Fehler beim Laden: $e', stack));
              if (contextSB.mounted) {
                try {
                  debugPrint('DokumenteSheet: Fehler beim Laden: $e');
                  messenger?.showSnackBar(SnackBar(content: Text('Fehler beim Laden der Dokumente: $e')));
                } catch (_) {}
              }
            } finally {
              if (contextSB.mounted) {
                setStateSB(() { loading = false; });
              }
            }
          }

          if (!hasScheduledInitialLoad) {
            hasScheduledInitialLoad = true;
            Future.microtask(loadFiles);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
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
                            setStateSB(() { files = sortFilesByName(files); });
                          } else if (v == 'type') {
                            setStateSB(() { files = sortFilesByTypeThenName(files); });
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'name', child: Text('Sortiere nach Name')),
                          PopupMenuItem(value: 'type', child: Text('Sortiere nach Typ')),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => loadFiles(),
                          child: files.isEmpty
                              ? ListView(children: const [SizedBox(height: 80), Center(child: Text('Keine Dokumente vorhanden.'))])
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  itemCount: files.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final file = files[i];
                                    final ext = file.contains('.') ? file.split('.').last.toLowerCase() : '';
                                    Widget leadingWidget;
                                    Widget? subtitleWidget;
                                    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
                                      leadingWidget = ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                          width: 72,
                                          height: 48,
                                          child: currentConfig != null
                                              ? CachedNetworkImage(
                                                  imageUrl: currentConfig!.webDavRoot.resolve('${widget.artikelId}/$file').toString(),
                                                  fit: BoxFit.cover,
                                                  placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                  errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                                                )
                                              : const Icon(Icons.broken_image),
                                        ),
                                      );
                                      subtitleWidget = const Text('Bilddatei', style: TextStyle(fontSize: 12, color: Colors.grey));
                                    } else if (ext == 'pdf') {
                                      leadingWidget = const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36);
                                      subtitleWidget = const Text('PDF-Datei', style: TextStyle(fontSize: 12, color: Colors.grey));
                                    } else if (['doc', 'docx', 'odt'].contains(ext)) {
                                      leadingWidget = const Icon(Icons.description, color: Colors.green, size: 36);
                                      subtitleWidget = const Text('Textdokument', style: TextStyle(fontSize: 12, color: Colors.grey));
                                    } else {
                                      leadingWidget = const Icon(Icons.insert_drive_file, size: 36);
                                      subtitleWidget = null;
                                    }

                                    final isDownloading = downloading[i] == true;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      elevation: 1,
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        leading: leadingWidget,
                                        title: Text(file, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: subtitleWidget,
                                        trailing: isDownloading ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.open_in_new),
                                        onTap: () async {
                                          setStateSB(() { downloading[i] = true; });
                                          unawaited(AppLogService().log('Dokumente: Download gestartet für $file (artikel ${widget.artikelId})'));
                                          final credsTap = widget.credentialsReader != null ? await widget.credentialsReader!() : await NextcloudCredentialsStore().read();
                                          if (!mounted || credsTap == null || widget.artikelId == null) {
                                            setStateSB(() { downloading.remove(i); });
                                            unawaited(AppLogService().log('Dokumente: Abbruch Download - fehlende Credentials oder ArtikelId'));
                                            return;
                                          }
                                          final cfg = NextcloudConfig(
                                            serverBase: credsTap.server,
                                            username: credsTap.user,
                                            appPassword: credsTap.appPw,
                                            baseRemoteFolder: credsTap.baseFolder,
                                          );
                                          final clientTap = NextcloudWebDavClient(cfg);
                                          final tempDir = await getTemporaryDirectory();
                                          final tempPath = '${tempDir.path}/$file';
                                          try {
                                            await clientTap.downloadFile('${widget.artikelId}/$file', tempPath);
                                            unawaited(AppLogService().log('Dokumente: Download erfolgreich für $file -> $tempPath'));
                                            if (!mounted) return;
                                            final result = await OpenFile.open(tempPath);
                                            if (!mounted) return;
                                            if (result.type == ResultType.done) {
                                              unawaited(AppLogService().log('Dokumente: Datei geöffnet: $file'));
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Datei geöffnet: $file')));
                                            } else {
                                              unawaited(AppLogService().logError('Dokumente: Datei konnte nicht geöffnet werden: ${result.message}', StackTrace.current));
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Datei konnte nicht geöffnet werden: ${result.message}')));
                                            }
                                          } catch (e, st) {
                                            if (!mounted) return;
                                            unawaited(AppLogService().logError('Dokumente: Fehler beim Download/Öffnen: $e', st));
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Öffnen: $e')));
                                          } finally {
                                            if (mounted) setStateSB(() { downloading.remove(i); });
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String countText;
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
