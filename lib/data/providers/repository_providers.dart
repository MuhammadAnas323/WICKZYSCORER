import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/team_repository.dart';
import 'package:sportyapp/data/repositories/player_repository.dart';
import 'package:sportyapp/data/repositories/tournament_repository.dart';
import 'package:sportyapp/data/repositories/news_repository.dart';
import 'package:sportyapp/data/repositories/video_repository.dart';
import 'package:sportyapp/data/repositories/user_repository.dart';
import 'package:sportyapp/data/repositories/fixture_repository.dart';
import 'package:sportyapp/data/repositories/notification_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreMatchRepository(firestore);
});

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreTeamRepository(firestore);
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestorePlayerRepository(firestore);
});

final tournamentRepositoryProvider = Provider<TournamentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreTournamentRepository(firestore);
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreNewsRepository(firestore);
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreVideoRepository(firestore);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreUserRepository(firestore);
});

final fixtureRepositoryProvider = Provider<FixtureRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreFixtureRepository(firestore);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreNotificationRepository(firestore);
});
