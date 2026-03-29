// lib/widgets/image_crop_dialog.dart
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../services/app_log_service.dart';
import '../utils/image_processing_utils.dart';

class ImageCropDialogResult {
  final Uint8List bytes;
  final bool cropped;

  const ImageCropDialogResult({
    required this.bytes,
    required this.cropped,
  });
}

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
  final _logger = AppLogService.logger;
  final CropController _controller = CropController();
  bool _isCropping = false;
  bool _isCropMode = false;
  late Uint8List _workingBytes;
  bool _imageReady = false;

  @override
  void initState() {
    super.initState();
    _workingBytes = widget.originalBytes;

    // DEBUG: Prüfe ob Bytes ein gültiges Bild sind
    final header = widget.originalBytes.length >= 4
        ? widget.originalBytes.sublist(0, 4).toString()
        : 'zu kurz';
    _logger.d(
          'ImageCropDialog: initState – '
          'bytes.length=${widget.originalBytes.length}, '
          'aspectRatio=${widget.aspectRatio}, '
          'first4bytes=$header',
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _imageReady = true);
        _logger.d('ImageCropDialog: imageReady=true');
      }
    });
  }

  Future<void> _handleCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _logger.d('ImageCropDialog: Crop gestartet');
    _controller.crop();
  }

  Future<void> _handleRotate() async {
    if (_isCropping) return;
    _logger.d('ImageCropDialog: Rotation gestartet');
    setState(() => _imageReady = false);

    final rotated =
        await ImageProcessingUtils.rotateClockwise(_workingBytes);
    if (!mounted) return;

    _logger.d(
      'ImageCropDialog: Rotation fertig – bytes.length=${rotated.length}',
    );
    setState(() {
      _workingBytes = rotated;
      _imageReady = true;
    });

    if (_isCropMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _controller.image = rotated;
          } catch (e) {
            _logger.w(
              'ImageCropDialog: controller.image setzen fehlgeschlagen: $e',
            );
          }
        }
      });
    }
  }

  void _toggleCropMode() {
    if (_isCropping) return;
    final nextMode = !_isCropMode;
    _logger.d('ImageCropDialog: toggleCropMode → $nextMode');
    setState(() {
      _isCropMode = nextMode;
      if (!nextMode) {
        _isCropping = false;
      }
    });
    if (nextMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _controller.image = _workingBytes;
        } catch (e) {
          _logger.w(
            'ImageCropDialog: controller.image setzen fehlgeschlagen: $e',
          );
        }
      });
    }
  }

  Future<void> _handleAccept() async {
    if (_isCropMode) {
      await _handleCrop();
    } else {
      _logger.d(
        'ImageCropDialog: Übernehmen ohne Crop – '
        'bytes.length=${_workingBytes.length}',
      );
      Navigator.of(context).pop(
        ImageCropDialogResult(bytes: _workingBytes, cropped: false),
      );
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCropping ? null : _handleRotate,
                      icon: const Icon(Icons.rotate_right),
                      label: const Text('90° drehen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCropping ? null : _toggleCropMode,
                      icon: Icon(
                        _isCropMode ? Icons.crop_square : Icons.crop,
                      ),
                      label: Text(
                        _isCropMode ? 'Zuschneiden aus' : 'Zuschneiden',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildImageArea()),
            const SizedBox(height: 12),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      onPressed: _isCropping ? null : _handleAccept,
                      child: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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

  Widget _buildImageArea() {
    if (!_imageReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isCropMode) {
      return Crop(
        key: ValueKey('crop_${_workingBytes.length}_${identityHashCode(_workingBytes)}'),
        controller: _controller,
        image: _workingBytes,
        aspectRatio: widget.aspectRatio,
        baseColor: Colors.black,
        maskColor: const Color.fromRGBO(0, 0, 0, 0.5),
        progressIndicator: const Center(child: CircularProgressIndicator()),
        interactive: true,
        onCropped: (result) {
          if (!mounted) return;
          setState(() => _isCropping = false);
          switch (result) {
            case CropSuccess(:final croppedImage):
              _logger.d(
                'ImageCropDialog: Crop erfolgreich – '
                'bytes.length=${croppedImage.length}',
              );
              Navigator.of(context).pop(
                ImageCropDialogResult(bytes: croppedImage, cropped: true),
              );
            case CropFailure(:final cause):
              _logger.e('ImageCropDialog: Crop fehlgeschlagen: $cause');
              ScaffoldMessenger.of(context).showSnackBar(
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
              if (_isCropping) _controller.crop();
            case CropStatus.cropping:
              break;
            case CropStatus.loading:
            case CropStatus.nothing:
              if (_isCropping) setState(() => _isCropping = false);
          }
        },
      );
    }

    // Vorschau-Modus
    return LayoutBuilder(
      builder: (context, constraints) {
        _logger.d(
          'ImageCropDialog: Vorschau ${constraints.maxWidth.toInt()}'
          'x${constraints.maxHeight.toInt()}',
        );
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: Colors.black,
          child: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(
                Uint8List.fromList(_workingBytes),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  _logger.e(
                    'ImageCropDialog: Image.memory Fehler',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Bild konnte nicht geladen werden',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}