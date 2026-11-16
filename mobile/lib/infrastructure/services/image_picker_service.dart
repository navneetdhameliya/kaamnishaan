import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../shared/app_logger.dart';

/// A photo the person picked, ready to upload.
class PickedImage {
  const PickedImage({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

enum PickSource { camera, gallery }

/// Takes or chooses a photo (profile photo, company logo). Returns null if the person cancels.
abstract class IImagePickerService {
  Future<PickedImage?> pick(PickSource source, {double maxSide = 1024});
}

class ImagePickerService implements IImagePickerService {
  ImagePickerService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const _types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};

  @override
  Future<PickedImage?> pick(PickSource source, {double maxSide = 1024}) async {
    try {
      final file = await _picker.pickImage(
        source: source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: 85,
      );
      if (file == null) return null;
      final ext = file.name.split('.').last.toLowerCase();
      final type = file.mimeType ?? _types[ext] ?? 'image/jpeg';
      return PickedImage(bytes: await file.readAsBytes(), contentType: type);
    } catch (e) {
      AppLogger.error('Picking a photo failed', error: e);
      return null;
    }
  }
}
