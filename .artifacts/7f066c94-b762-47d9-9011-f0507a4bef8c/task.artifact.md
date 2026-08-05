# Task List - Scorer Creation & Team Input Fixes

- [x] **Tournament Creation Navigation**
    - [x] Fix `TournamentManagementScreen` to navigate back after save.
    - [x] Add error handling and loading feedback.

- [x] **Match Creation Loading**
    - [x] Fix `CreateLocalMatchScreen` continuous loading issue.
    - [x] Add `try-finally` to ensure state is reset.

- [x] **Friendly Match Team Entry**
    - [x] Update `MatchSetupScreen` to allow manual team name entry.
    - [x] Implement team resolution logic (existing vs new).

- [x] **Syntax & Build Fixes**
    - [x] Escape `$` in string literals for tournament screens.
    - [x] Clean up duplicated code in `TeamSetupScreen`.
    - [x] Fix `Gap` and import issues in Team screens.
    - [x] Fix `l10n` getter in `CreateLocalMatchScreen`.

- [x] **Final Verification**
    - [x] Run `dart analyze lib/`.
