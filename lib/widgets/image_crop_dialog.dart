import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class ImageCropDialog extends StatefulWidget {
  final Uint8List originalBytes;
  final double aspectRatio;

  const ImageCropDialog({
    super.key,
    required this.originalBytes,
    required this.aspectRatio,
  });

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final CropController _controller = CropController();
  bool _isCropping = false;

  void _handleCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Bild zuschneiden',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: Crop(
                controller: _controller,
                image: widget.originalBytes,
                aspectRatio: widget.aspectRatio,
                baseColor: Colors.black,
                maskColor: const Color.fromRGBO(0, 0, 0, 0.5),
                progressIndicator: const Center(
                  child: CircularProgressIndicator(),
                ),
                interactive: true,
                onCropped: (result) {
                  if (!mounted) return;
                  if (_isCropping) {
                    setState(() => _isCropping = false);
                  }
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      Navigator.of(context).pop(croppedImage);
                      break;
                    case CropFailure(:final cause):
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text('Zuschneiden fehlgeschlagen: $cause'),
                        ),
                      );
                  }
                },
                onStatusChanged: (status) {
                  if (!mounted) return;
                  switch (status) {
                    case CropStatus.ready:
                      if (_isCropping) {
                        _controller.crop();
                      }
                      break;
                    case CropStatus.cropping:
                      break;
                    case CropStatus.loading:
                    case CropStatus.nothing:
                      if (_isCropping) {
                        setState(() => _isCropping = false);
                      }
                      break;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCropping
                          ? null
                          : () => Navigator.of(context).pop(null),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isCropping ? null : _handleCrop,
                      child: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Übernehmen'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}