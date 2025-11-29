import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;

Future<String?> uploadImage() async {
  if (kIsWeb) {
    // Web: dùng bytes
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    }
    return null;
  } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
    // Mobile: dùng image_picker hoặc file_picker + File
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    }
    return null;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.fuchsia) {
    // Desktop: dùng file_picker + File
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    }
    return null;
  }
  return null;
}