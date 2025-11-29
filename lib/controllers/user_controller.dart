import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserController {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '141493579332-h9nq4qvl7o0h0hm517lapo7gn9crdmst.apps.googleusercontent.com'
        : null,
  );
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<UserModel?> signInWithGoogle() async {
    final user = await _googleSignIn.signIn();
    if (user != null) {
      final query = await usersCollection.where('email', isEqualTo: user.email).limit(1).get();
      if (query.docs.isEmpty) {
        final userModel = UserModel(
          name: user.displayName,
          email: user.email,
          avatar: user.photoUrl,
          phone: null,
          password: null,
          isGoogleAccount: 1,
          is2FAEnabled: 1,
        );
        await usersCollection.add(userModel.toMap());
        return userModel;
      } else {
        return UserModel.fromMap(query.docs.first.data() as Map<String, dynamic>);
      }
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final query = await usersCollection.where('email', isEqualTo: email).limit(1).get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data() as Map<String, dynamic>);
    }
    return null;
  }
    Future<void> createUser(UserModel user) async {
    await usersCollection.add(user.toMap());
  }
    Future<void> updateUserAvatarByEmail(String email, String avatarUrl) async {
    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (users.docs.isNotEmpty) {
      await users.docs.first.reference.update({'avatar': avatarUrl});
    }
  }
  Future<void> updateUser(UserModel user) async {
    // Không cho phép sửa email và phone
    final users = await usersCollection
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    if (users.docs.isNotEmpty) {
      await users.docs.first.reference.update({
        'name': user.name,
        'avatar': user.avatar,
        'password': user.password,
        'isGoogleAccount': user.isGoogleAccount,
        'is2FAEnabled': user.is2FAEnabled,
      });
    }
  }
   Future<UserModel?> getUserByPhone(String phone) async {
    final firestore = FirebaseFirestore.instance;
    final snap = await firestore.collection('users').where('phone', isEqualTo: phone).limit(1).get();
    if (snap.docs.isNotEmpty) {
      return UserModel.fromMap(snap.docs.first.data());
    }
    return null;
  }
}