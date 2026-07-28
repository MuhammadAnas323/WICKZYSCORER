import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/utils/m3u_parser.dart';
import 'package:sportyapp/data/models/m3u_channel_model.dart';

class M3uService {
  static const Duration _fetchTimeout = Duration(seconds: 20);

  Future<M3uPlaylist> fetchAndParse(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
        })
        .timeout(_fetchTimeout);

    if (response.statusCode != 200) {
      throw HttpException('Failed to fetch playlist: HTTP ${response.statusCode}');
    }

    return M3uParser.parse(response.body, url);
  }

  Future<void> cachePlaylist(M3uPlaylist playlist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(M3uPlaylist.prefKey, jsonEncode(playlist.toJson()));
  }

  Future<M3uPlaylist?> loadCachedPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(M3uPlaylist.prefKey);
    if (cached == null) return null;
    try {
      return M3uPlaylist.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(M3uPlaylist.prefKey);
  }
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => message;
}
