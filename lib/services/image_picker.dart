//.../services/image_picker.dart

import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';


class PickedImage {
  final String? pfad;
  final Uint8List? bytes;
  final String? dateiname;

  PickedImage({this.pfad, this.bytes, this.dateiname});
}

class ImagePickerService {
  /// Wählt ein Bild aus einer Datei
  static Future<PickedImage> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return PickedImage();
    final file = result.files.single;
    return PickedImage(
      pfad: file.path,
      bytes: file.bytes,
      dateiname: file.name,
    );
  }

  /// Nimmt ein Bild mit der Kamera auf
  static Future<PickedImage> pickImageCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return PickedImage();
    final bytes = await pickedFile.readAsBytes();
    return PickedImage(
      pfad: pickedFile.path,
      bytes: bytes,
      dateiname: pickedFile.name,
    );
  }
}