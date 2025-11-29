import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

Future<String?> uploadImage() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result != null && result.files.single.path != null) {
    final file = File(result.files.single.path!);
    final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
  return null;
}