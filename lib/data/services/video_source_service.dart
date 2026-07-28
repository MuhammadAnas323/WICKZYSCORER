import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/video_source_model.dart';

class VideoSourceService {
  final FirebaseFunctions _functions;
  static const String _functionName = 'resolveVideoSource';
  static const Duration _timeout = Duration(seconds: 25);

  VideoSourceService(this._functions);

  Future<VideoSourceResult> resolve(String url) async {
    final result = await _functions
        .httpsCallable(_functionName)
        .call<Map<String, dynamic>>({'url': url})
        .timeout(_timeout);

    return VideoSourceResult.fromJson(result.data);
  }

  Future<VideoSourceSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(VideoSourceSettings.prefKey);
    if (cached != null) {
      return VideoSourceSettings.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    return const VideoSourceSettings();
  }

  Future<void> saveSettings(VideoSourceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(VideoSourceSettings.prefKey, jsonEncode(settings.toJson()));
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(VideoSourceSettings.prefKey);
  }
}
