import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/admin_settings.dart';
import 'package:sportyapp/data/services/admin_settings_service.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

final adminSettingsServiceProvider = Provider<AdminSettingsService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AdminSettingsService(firestore);
});

final adminSettingsProvider = StateNotifierProvider<AdminSettingsNotifier, AsyncValue<AdminSettings>>((ref) {
  final service = ref.watch(adminSettingsServiceProvider);
  return AdminSettingsNotifier(service);
});

class AdminSettingsNotifier extends StateNotifier<AsyncValue<AdminSettings>> {
  final AdminSettingsService _service;

  AdminSettingsNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final settings = await _service.load();
    state = AsyncValue.data(settings);
  }

  Future<void> save(AdminSettings settings) async {
    state = const AsyncValue.loading();
    try {
      await _service.save(settings.copyWith(updatedAt: DateTime.now()));
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clear() async {
    await _service.clear();
    state = const AsyncValue.data(AdminSettings());
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    final settings = await _service.loadFromFirestore();
    state = AsyncValue.data(settings);
  }
}
