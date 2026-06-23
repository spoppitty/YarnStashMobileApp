import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class YarnImageStorageService {
  YarnImageStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadYarnImage({
    required String uid,
    required String yarnId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last.toLowerCase();
    final safeExtension = extension.isEmpty ? 'jpg' : extension;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('yarns')
        .child(yarnId)
        .child(fileName);

    final uploadTask = await ref.putFile(imageFile);

    return uploadTask.ref.getDownloadURL();
  }

  Future<void> deleteImageByUrl(String imageUrl) async {
    await _storage.refFromURL(imageUrl).delete();
  }
}