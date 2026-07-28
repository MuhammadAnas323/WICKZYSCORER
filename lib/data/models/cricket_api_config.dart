import 'dart:convert';

enum CricketApiStatus {
  connected,
  error,
  testing,
  idle,
}

class CricketApiConfig {
  final String id;
  final String name;
  final String endpointUrl;
  final String apiKey;
  final String apiType; // 'restJson', 'm3uPlaylist', 'cricbuzz', 'customFeed'
  final bool isActive;
  final CricketApiStatus status;
  final DateTime? lastTestedAt;
  final String? errorMessage;
  final bool isPreset;

  const CricketApiConfig({
    required this.id,
    required this.name,
    required this.endpointUrl,
    this.apiKey = '',
    this.apiType = 'restJson',
    this.isActive = true,
    this.status = CricketApiStatus.idle,
    this.lastTestedAt,
    this.errorMessage,
    this.isPreset = false,
  });

  CricketApiConfig copyWith({
    String? id,
    String? name,
    String? endpointUrl,
    String? apiKey,
    String? apiType,
    bool? isActive,
    CricketApiStatus? status,
    DateTime? lastTestedAt,
    String? errorMessage,
    bool? isPreset,
  }) {
    return CricketApiConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      apiKey: apiKey ?? this.apiKey,
      apiType: apiType ?? this.apiType,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'endpointUrl': endpointUrl,
      'apiKey': apiKey,
      'apiType': apiType,
      'isActive': isActive,
      'status': status.name,
      'lastTestedAt': lastTestedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'isPreset': isPreset,
    };
  }

  factory CricketApiConfig.fromMap(Map<String, dynamic> map) {
    return CricketApiConfig(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      endpointUrl: map['endpointUrl'] ?? '',
      apiKey: map['apiKey'] ?? '',
      apiType: map['apiType'] ?? 'restJson',
      isActive: map['isActive'] ?? true,
      status: _statusFromString(map['status']),
      lastTestedAt: map['lastTestedAt'] != null
          ? DateTime.tryParse(map['lastTestedAt'])
          : null,
      errorMessage: map['errorMessage'],
      isPreset: map['isPreset'] ?? false,
    );
  }

  static CricketApiStatus _statusFromString(String? statusStr) {
    switch (statusStr) {
      case 'connected':
        return CricketApiStatus.connected;
      case 'error':
        return CricketApiStatus.error;
      case 'testing':
        return CricketApiStatus.testing;
      case 'idle':
      default:
        return CricketApiStatus.idle;
    }
  }

  String toJson() => json.encode(toMap());

  factory CricketApiConfig.fromJson(String source) =>
      CricketApiConfig.fromMap(json.decode(source));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CricketApiConfig &&
        other.id == id &&
        other.name == name &&
        other.endpointUrl == endpointUrl &&
        other.apiKey == apiKey &&
        other.apiType == apiType &&
        other.isActive == isActive &&
        other.status == status &&
        other.lastTestedAt == lastTestedAt &&
        other.errorMessage == errorMessage &&
        other.isPreset == isPreset;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        endpointUrl.hashCode ^
        apiKey.hashCode ^
        apiType.hashCode ^
        isActive.hashCode ^
        status.hashCode ^
        lastTestedAt.hashCode ^
        errorMessage.hashCode ^
        isPreset.hashCode;
  }
}
