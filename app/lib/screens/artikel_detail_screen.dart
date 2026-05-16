// lib/screens/artikel_detail_screen.dart
//
// F-011.7: Scaffold-Wrapper um ArtikelDetailContent.
// Verwendet ValueNotifier für Rebuild-Synchronisation mit Content.

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';
import '../widgets/artikel_detail_content.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  State<ArtikelDetailScreen> createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  final GlobalKey<ArtikelDetailContentState> _contentKey = GlobalKey();

  /// Wird vom Content bei jedem setState inkrementiert → Wrapper rebuilt.
  final ValueNotifier<int> _rebuildNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _rebuildNotifier.dispose();
    super.dispose();
  }

  void _triggerRebuild() {
    _rebuildNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<int>(
      valueListenable: _rebuildNotifier,
      builder: (context, _, __) {
        final contentState = _contentKey.currentState;

        return PopScope(
          canPop: !(contentState?.hasUnsavedChanges ?? false),
          onPopInvokedWithResult: (didPop, _) async {
            if (!mounted) return;
            if (didPop) return;

            final nav = Navigator.of(context);

            final discard = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Änderungen verwerfen?'),
                content: const Text(
                  'Ungespeicherte Änderungen gehen verloren.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Weiter bearbeiten'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Verwerfen'),
                  ),
                ],
              ),
            );

            if (discard != true) return;
            nav.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(contentState?.titleText ?? widget.artikel.name),
              actions: contentState?.buildActions(colorScheme) ?? [],
            ),
            body: ArtikelDetailContent(
              key: _contentKey,
              artikel: widget.artikel,
              embedded: false,
              onSaved: (gespeicherterArtikel) {
                Navigator.pop(context, gespeicherterArtikel);
              },
              onDeleted: () {
                Navigator.pop(context, null);
              },
              onStateChanged: _triggerRebuild,
            ),
          ),
        );
      },
    );
  }
}