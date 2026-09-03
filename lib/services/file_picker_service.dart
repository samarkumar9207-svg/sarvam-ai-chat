/// File and image picker service.
///
/// Uses file_picker and image_picker to let users attach images or files
/// to their messages.

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';

class FilePickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from the gallery.
  Future<Attachment?> pickImage() async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.mimeType ?? 'image/jpeg';

    return Attachment.fromBytes(
      fileName: xFile.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  /// Take a photo with the camera.
  Future<Attachment?> takePhoto() async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.mimeType ?? 'image/jpeg';

    return Attachment.fromBytes(
      fileName: xFile.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  /// Pick any file (PDF, text, etc.) from the device.
  Future<Attachment?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.bytes == null && file.path == null) return null;

    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      bytes = await File(file.path!).readAsBytes();
    }

    return Attachment.fromBytes(
      fileName: file.name,
      bytes: bytes,
      mimeType: 'application/octet-stream',
    );
  }
}
