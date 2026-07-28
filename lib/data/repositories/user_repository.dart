import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/user_model.dart';

abstract class UserRepository {
  Future<UserModel?> getUserById(String id);
  Future<UserModel?> getUserByEmail(String email);
  Future<void> createUser(UserModel user);
  Future<void> updateUser(String id, Map<String, dynamic> updates);
  Future<bool> isAdmin(String userId);
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository(this._firestore);

  @override
  Future<UserModel?> getUserById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return UserModel.fromJson({...doc.data(), 'id': doc.id});
  }

  @override
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toJson());
  }

  @override
  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(id).update(updates);
  }

  @override
  Future<bool> isAdmin(String userId) async {
    final user = await getUserById(userId);
    return user?.isAdmin ?? false;
  }
}
