import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/team_model.dart';
import 'package:sportyapp/data/repositories/team_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

final teamDetailProvider = FutureProvider.family<TeamModel?, String>(
  (ref, id) => ref.read(teamRepositoryProvider).getTeamById(id));
