import 'package:flutter_riverpod/flutter_riverpod.dart';

final roleSelectionViewModelProvider = Provider<RoleSelectionViewModel>((ref) {
  return RoleSelectionViewModel();
});

class RoleSelectionViewModel {
  // Navigation intent can be handled directly in the view, so this is minimal.
}
