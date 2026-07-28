import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/cricket_api_config.dart';
import 'package:sportyapp/data/models/cricket_feed_item.dart';

class CricketApiService {
  static const String _localCacheKey = 'sportyapp_cricket_apis_v1';

  // Firestore path: a single document holding the list of API configs as a JSON array.
  // This makes every device share the same API list.
  static const String _firestoreCollection = 'app_config';
  static const String _firestoreDoc = 'cricket_apis';

  static final List<CricketApiConfig> defaultPresets = const [];

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Loads API configurations.
  /// Priority: Firestore (shared across devices) → local SharedPreferences cache.
  /// Automatically purges any legacy dummy/preset APIs from both stores.
  Future<List<CricketApiConfig>> loadApis() async {
    try {
      final doc = await _db
          .collection(_firestoreCollection)
          .doc(_firestoreDoc)
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists && doc.data() != null) {
        final raw = doc.data()!['apis'];
        if (raw is List) {
          final list = raw
              .map((item) => CricketApiConfig.fromMap(Map<String, dynamic>.from(item as Map)))
              .where((item) => !item.isPreset && !item.id.startsWith('preset_'))
              .toList();
          // Write-through to local cache for offline fallback
          await _saveToLocalCache(list);
          return list;
        }
      }
    } catch (_) {
      // Firestore unavailable — fall back to local cache
    }

    return _loadFromLocalCache();
  }

  /// Saves list of API configurations to Firestore (shared) and local cache.
  Future<void> saveApis(List<CricketApiConfig> apis) async {
    final clean = apis
        .where((a) => !a.isPreset && !a.id.startsWith('preset_'))
        .toList();

    // Persist to Firestore so all devices see the change immediately
    try {
      final listMap = clean.map((a) => a.toMap()).toList();
      await _db
          .collection(_firestoreCollection)
          .doc(_firestoreDoc)
          .set({'apis': listMap}, SetOptions(merge: false));
    } catch (_) {
      // If offline, Firestore will sync when connectivity is restored
    }

    // Also write to local cache for fast offline reads
    await _saveToLocalCache(clean);
  }

  Future<void> _saveToLocalCache(List<CricketApiConfig> apis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = apis.map((a) => a.toMap()).toList();
      await prefs.setString(_localCacheKey, json.encode(listMap));
    } catch (_) {}
  }

  Future<List<CricketApiConfig>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_localCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        return decoded
            .map((item) => CricketApiConfig.fromMap(item as Map<String, dynamic>))
            .where((item) => !item.isPreset && !item.id.startsWith('preset_'))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Returns a real-time stream of API configs from Firestore.
  /// Widgets can watch this to automatically refresh when another device
  /// adds or removes an API.
  Stream<List<CricketApiConfig>> watchApis() {
    return _db
        .collection(_firestoreCollection)
        .doc(_firestoreDoc)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <CricketApiConfig>[];
      final raw = doc.data()!['apis'];
      if (raw is! List) return <CricketApiConfig>[];
      return raw
          .map((item) => CricketApiConfig.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((item) => !item.isPreset && !item.id.startsWith('preset_'))
          .toList();
    });
  }

  /// Tests connectivity to a single API endpoint.
  Future<CricketApiConfig> testApiConnection(CricketApiConfig config) async {
    final startTime = DateTime.now();
    try {
      final headers = <String, String>{
        'User-Agent': 'SportyApp/1.0',
        'Accept': '*/*',
      };
      if (config.apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${config.apiKey}';
        headers['X-API-Key'] = config.apiKey;
      }

      final uri = Uri.parse(config.endpointUrl);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return config.copyWith(
          status: CricketApiStatus.connected,
          lastTestedAt: startTime,
          errorMessage: null,
        );
      } else {
        return config.copyWith(
          status: CricketApiStatus.error,
          lastTestedAt: startTime,
          errorMessage: 'Server returned HTTP status ${response.statusCode}',
        );
      }
    } on TimeoutException {
      return config.copyWith(
        status: CricketApiStatus.error,
        lastTestedAt: startTime,
        errorMessage: 'Connection timed out (5s limit)',
      );
    } catch (e) {
      return config.copyWith(
        status: CricketApiStatus.error,
        lastTestedAt: startTime,
        errorMessage: 'Connection error: ${e.toString()}',
      );
    }
  }

  /// Fetches feeds from a given API configuration endpoint.
  Future<List<CricketFeedItem>> fetchFeedFromApi(CricketApiConfig config) async {
    if (!config.isActive) return [];

    final url = config.endpointUrl.trim();
    if (url.isEmpty) return [];

    // ── Direct stream URL detection ───────────────────────────────────────────
    // If the saved endpoint URL is itself a playable stream (not a data API),
    // return exactly ONE channel card without fetching anything.
    final lowerUrl = url.toLowerCase();
    final isDirectStream = lowerUrl.endsWith('.m3u8') ||
        lowerUrl.endsWith('.mpd') ||
        lowerUrl.endsWith('.mp4') ||
        lowerUrl.contains('stream.mux.com') ||
        lowerUrl.contains('.akamaihd.net') ||
        lowerUrl.contains('manifest') ||
        lowerUrl.contains('playlist');

    if (isDirectStream) {
      return [
        CricketFeedItem(
          id: 'direct_stream_${config.id}',
          title: config.name,
          subtitle: 'Live Stream • ${config.apiType.toUpperCase()}',
          status: 'CHANNEL',
          streamUrl: url,
          imageUrl: '',
          apiSourceId: config.id,
          apiSourceName: config.name,
          format: 'LIVE STREAM',
        ),
      ];
    }
    // ── End direct stream detection ───────────────────────────────────────────

    try {
      final headers = <String, String>{
        'User-Agent': 'SportyApp/1.0',
        'Accept': '*/*',
      };
      if (config.apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${config.apiKey}';
        headers['X-API-Key'] = config.apiKey;
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (config.apiType == 'm3uPlaylist' || body.startsWith('#EXTM3U')) {
          return _parseM3uFeed(body, config);
        } else {
          final decoded = json.decode(body);
          return _parseJsonFeed(decoded, config);
        }
      }
    } catch (_) {
      // Network or parse error – fall through to empty list
    }

    return _getFallbackFeedForApi(config);
  }

  List<CricketFeedItem> _parseJsonFeed(dynamic decoded, CricketApiConfig config) {
    final List<CricketFeedItem> items = [];
    List<dynamic> rawList = [];

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['matches'] is List) {
        rawList = decoded['matches'];
      } else if (decoded['data'] is List) {
        rawList = decoded['data'];
      } else if (decoded['typeMatches'] is List) {
        rawList = decoded['typeMatches'];
      } else {
        rawList = [decoded];
      }
    }

    for (var i = 0; i < rawList.length; i++) {
      final itemMap = rawList[i];
      if (itemMap is Map<String, dynamic>) {
        items.add(CricketFeedItem.fromMap(
          itemMap,
          apiSourceId: config.id,
          apiSourceName: config.name,
        ));
      }
    }
    return items;
  }

  List<CricketFeedItem> _parseM3uFeed(String content, CricketApiConfig config) {
    final List<CricketFeedItem> items = [];
    final lines = content.split('\n');
    String? currentTitle;
    String currentLogo = '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXTINF:')) {
        // Parse the channel name after the last comma
        final nameMatch = RegExp(r',(.+)$').firstMatch(trimmed);
        currentTitle = nameMatch?.group(1)?.trim() ?? 'Sports Channel';

        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(trimmed);
        currentLogo = logoMatch?.group(1) ?? '';
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        // Only add a channel if we have a preceding #EXTINF line (i.e. title was set)
        if (currentTitle != null) {
          items.add(CricketFeedItem(
            id: 'm3u_${items.length}_${trimmed.hashCode}_${config.id}',
            title: currentTitle,
            subtitle: 'Live Stream Channel • M3U',
            status: 'CHANNEL',
            streamUrl: trimmed,
            imageUrl: currentLogo,
            apiSourceId: config.id,
            apiSourceName: config.name,
            format: 'LIVE STREAM',
          ));
        }
        // Reset for next entry
        currentTitle = null;
        currentLogo = '';
      }
    }
    return items;
  }

  List<CricketFeedItem> _getFallbackFeedForApi(CricketApiConfig config) {
    // Return empty list so no fake or dummy data is displayed to the user
    return [];
  }
}
