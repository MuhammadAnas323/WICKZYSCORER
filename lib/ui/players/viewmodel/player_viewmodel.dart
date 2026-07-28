import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/player_model.dart';
import 'package:sportyapp/data/repositories/player_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

final playerDetailProvider = FutureProvider.family<PlayerModel?, String>(
  (ref, id) => ref.read(playerRepositoryProvider).getPlayerById(id));
