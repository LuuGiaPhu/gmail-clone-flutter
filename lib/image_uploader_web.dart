import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> uploadImage() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result != null && result.files.single.bytes != null) {
    final fileBytes = result.files.single.bytes!;
    final fileName = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putData(fileBytes);
    return await ref.getDownloadURL();
  }
  return null;
}