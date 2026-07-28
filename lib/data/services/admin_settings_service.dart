import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/admin_settings.dart';

class AdminSettingsService {
  final FirebaseFirestore _firestore;

  AdminSettingsService(this._firestore);

  static const String _firestorePath = 'settings/admin/config';

  Future<AdminSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(AdminSettings.prefKey);
    if (cached != null) {
      return AdminSettings.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    return const AdminSettings();
  }

  Future<void> save(AdminSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AdminSettings.prefKey, jsonEncode(settings.toJson()));

    try {
      await _firestore.doc(_firestorePath).set({
        'apiBaseUrl': settings.apiBaseUrl,
        'apiKey': settings.apiKey,
        'apiHost': settings.apiHost,
        'videoUrl': settings.videoUrl,
        'videoMatchName': settings.videoMatchName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AdminSettings.prefKey);

    try {
      await _firestore.doc(_firestorePath).delete();
    } catch (_) {}
  }

  Future<AdminSettings> loadFromFirestore() async {
    try {
      final doc = await _firestore.doc(_firestorePath).get();
      if (doc.exists) {
        final data = doc.data()!;
        final settings = AdminSettings(
          apiBaseUrl: (data['apiBaseUrl'] as String?) ?? '',
          apiKey: (data['apiKey'] as String?) ?? '',
          apiHost: (data['apiHost'] as String?) ?? '',
          videoUrl: (data['videoUrl'] as String?) ?? '',
          videoMatchName: (data['videoMatchName'] as String?) ?? '',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AdminSettings.prefKey, jsonEncode(settings.toJson()));
        return settings;
      }
    } catch (_) {}
    return const AdminSettings();
  }
}
