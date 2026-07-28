import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SavedRecording {
  final String filePath;
  final String fileName;
  final int sizeBytes;
  final DateTime createdAt;

  SavedRecording({
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class RecordingRepository {
  Future<List<SavedRecording>> getSavedRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir.list().toList();
      final recordings = <SavedRecording>[];
      for (final entity in files) {
        final name = p.basename(entity.path);
        if (entity is File && (name.startsWith('sportyapp_stream_') || name.startsWith('sportyapp_screen_'))) {
          final stat = await entity.stat();
          recordings.add(SavedRecording(
            filePath: entity.path,
            fileName: name,
            sizeBytes: stat.size,
            createdAt: stat.modified,
          ));
        }
      }
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recordings;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteRecording(String filePath) async {
    try {
      await File(filePath).delete();
    } catch (_) {}
  }
}

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepository();
});

final savedRecordingsProvider = FutureProvider<List<SavedRecording>>((ref) {
  return ref.read(recordingRepositoryProvider).getSavedRecordings();
});
