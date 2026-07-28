import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sportyapp/core/constants/app_constants.dart';

class AgoraTokenService {
  final HttpsCallable _callable;

  AgoraTokenService(FirebaseFunctions functions)
      : _callable = functions.httpsCallable('generateAgoraToken');

  /// Returns the Agora token string.
  ///
  /// Checks in order:
  /// 1. Firebase Cloud Function `generateAgoraToken` (if deployed).
  /// 2. Pure Dart local token builder using `AppConstants.agoraAppCertificate` (if set).
  /// 3. Returns empty string `""` for Testing Mode.
  Future<String> fetchToken({
    required String channelName,
    required int uid,
  }) async {
    // 1. Try Cloud Function
    try {
      final result = await _callable.call(<String, dynamic>{
        'channelName': channelName,
        'uid': uid,
      });
      final token = result.data['token'] as String?;
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      // Cloud Function not deployed
    }

    // 2. Try local Dart RTC token generation if App Certificate is provided
    if (AppConstants.agoraAppCertificate.isNotEmpty) {
      try {
        final localToken = generateLocalRtcToken(
          appId: AppConstants.agoraAppId,
          appCertificate: AppConstants.agoraAppCertificate,
          channelName: channelName,
          uid: uid,
        );
        debugPrint('[AgoraTokenService] Generated local RTC token for $channelName (uid=$uid)');
        return localToken;
      } catch (e) {
        debugPrint('[AgoraTokenService] Local token generation failed: $e');
      }
    }

    // 3. Fallback to AppConstants.agoraTempToken if provided
    if (AppConstants.agoraTempToken.isNotEmpty) {
      debugPrint('[AgoraTokenService] Using AppConstants.agoraTempToken for $channelName');
      return AppConstants.agoraTempToken;
    }

    debugPrint(
      '[AgoraTokenService] Cloud Function not found & AppCertificate/agoraTempToken empty. '
      'Using empty token. If joinChannel fails with error 110 (invalid token), '
      'set project to "Testing Mode" in Agora Console or provide agoraTempToken in AppConstants.',
    );
    return '';
  }

  /// Pure Dart local Agora RTC Token Builder (v006 format).
  static String generateLocalRtcToken({
    required String appId,
    required String appCertificate,
    required String channelName,
    required int uid,
    int expireSeconds = 86400,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final privilegeExpireTs = now + expireSeconds;
    final salt = Random().nextInt(99999999) + 1;
    final uidStr = uid == 0 ? '' : uid.toString();

    // Pack message: appId + channelName + uidStr + salt + ts + privileges
    final messageBytes = BytesBuilder();

    // AppID bytes
    final appIdBytes = utf8.encode(appId);
    messageBytes.add(appIdBytes);

    // Channel name bytes with length prefix (uint16)
    final channelBytes = utf8.encode(channelName);
    final bdChanLen = ByteData(2)..setUint16(0, channelBytes.length, Endian.little);
    messageBytes.add(bdChanLen.buffer.asUint8List());
    messageBytes.add(channelBytes);

    // UID string bytes with length prefix (uint16)
    final uidBytes = utf8.encode(uidStr);
    final bdUidLen = ByteData(2)..setUint16(0, uidBytes.length, Endian.little);
    messageBytes.add(bdUidLen.buffer.asUint8List());
    messageBytes.add(uidBytes);

    // Salt (uint32)
    final bdSalt = ByteData(4)..setUint32(0, salt, Endian.little);
    messageBytes.add(bdSalt.buffer.asUint8List());

    // Timestamp (uint32)
    final bdTs = ByteData(4)..setUint32(0, now, Endian.little);
    messageBytes.add(bdTs.buffer.asUint8List());

    // Privileges (map of uint16 key -> uint32 expireTs)
    // Keys: 1 (join_channel), 2 (publish_audio), 3 (publish_video), 4 (publish_data_stream)
    final privileges = {
      1: privilegeExpireTs,
      2: privilegeExpireTs,
      3: privilegeExpireTs,
      4: privilegeExpireTs,
    };
    final bdPrivCount = ByteData(2)..setUint16(0, privileges.length, Endian.little);
    messageBytes.add(bdPrivCount.buffer.asUint8List());

    for (final entry in privileges.entries) {
      final bdKey = ByteData(2)..setUint16(0, entry.key, Endian.little);
      final bdVal = ByteData(4)..setUint32(0, entry.value, Endian.little);
      messageBytes.add(bdKey.buffer.asUint8List());
      messageBytes.add(bdVal.buffer.asUint8List());
    }

    // HMAC-SHA256 of messageBytes using appCertificate bytes as key
    final certBytes = utf8.encode(appCertificate);
    final hmac = Hmac(sha256, certBytes);
    final signature = hmac.convert(messageBytes.toBytes()).bytes;

    // Pack payload: signature + salt + ts + privileges
    final payloadBytes = BytesBuilder();
    final bdSigLen = ByteData(2)..setUint16(0, signature.length, Endian.little);
    payloadBytes.add(bdSigLen.buffer.asUint8List());
    payloadBytes.add(signature);
    payloadBytes.add(bdSalt.buffer.asUint8List());
    payloadBytes.add(bdTs.buffer.asUint8List());
    payloadBytes.add(bdPrivCount.buffer.asUint8List());
    for (final entry in privileges.entries) {
      final bdKey = ByteData(2)..setUint16(0, entry.key, Endian.little);
      final bdVal = ByteData(4)..setUint32(0, entry.value, Endian.little);
      payloadBytes.add(bdKey.buffer.asUint8List());
      payloadBytes.add(bdVal.buffer.asUint8List());
    }

    // Version "006" + appId + base64(payload)
    final base64Payload = base64.encode(payloadBytes.toBytes());
    return '006$appId$base64Payload';
  }
}

