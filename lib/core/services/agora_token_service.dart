import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgoraTokenService {
  AgoraTokenService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> fetchToken({
    required String channelName,
    required int uid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to fetch an Agora token.');
    }

    final callable = _functions.httpsCallable('generateAgoraToken');
    final result = await callable.call<Map<String, dynamic>>({
      'channelName': channelName,
      'uid': uid,
    });

    return result.data ?? {};
  }
}
