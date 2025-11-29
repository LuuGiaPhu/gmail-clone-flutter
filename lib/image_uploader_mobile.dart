import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

bool _isPicking = false;

Future<String?> uploadImage() async {
  if (_isPicking) return null;
  _isPicking = true;
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    }
    return null;
  } finally {
    _isPicking = false;
  }
}