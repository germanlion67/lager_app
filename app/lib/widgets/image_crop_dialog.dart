import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

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
  final CropController _controller = CropController();
  bool _isCropping = false;
  bool _isCropMode = false;
  late Uint8List _workingBytes;

  void _handleCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _controller.crop();
  }

  @override
  void initState() {
    super.initState();
    _workingBytes = widget.originalBytes;
  }

  Future<void> _handleRotate() async {
    if (_isCropping) return;
    final rotated = await ImageProcessingUtils.rotateClockwise(_workingBytes);
    if (!mounted) return;
    setState(() => _workingBytes = rotated);
    if (_isCropMode) {
      _controller.image = rotated;
    }
  }

  void _toggleCropMode() {
    if (_isCropping) return;
    final nextMode = !_isCropMode;
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
        } catch (_) {
          // Ignorieren, falls Controller noch nicht bereit ist.
        }
      });
    }
  }

  void _handleAccept() {
    if (_isCropMode) {
      _handleCrop();
    } else {
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
                      icon: Icon(_isCropMode ? Icons.crop_square : Icons.crop),
                      label: Text(_isCropMode ? 'Zuschneiden aus' : 'Zuschneiden'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isCropMode
                  ? Crop(
                      key: ValueKey(_workingBytes.hashCode),
                      controller: _controller,
                      image: _workingBytes,
                      aspectRatio: widget.aspectRatio,
                      baseColor: Colors.black,
                      maskColor: const Color.fromRGBO(0, 0, 0, 0.5),
                      progressIndicator: const Center(
                        child: CircularProgressIndicator(),
                      ),
                      interactive: true,
                      onCropped: (result) {
                        if (!mounted) return;
                        setState(() => _isCropping = false);
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            Navigator.of(context).pop(
                              ImageCropDialogResult(
                                bytes: croppedImage,
                                cropped: true,
                              ),
                            );
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
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.memory(
                            _workingBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
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
                      onPressed: _isCropping ? null : _handleAccept,
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