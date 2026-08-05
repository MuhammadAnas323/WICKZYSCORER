# Implementation Plan - Fix Scorer Creation & Team Input

This plan addresses reported issues in tournament and match creation, and improves team selection in the match setup wizard.

## Proposed Changes

### 1. Fix Tournament Creation Navigation
In `TournamentManagementScreen`, I will ensure that the screen reliably navigates back after a successful save. I'll also add a `try-catch` to handle potential save errors.

- [MODIFY] [tournament_management_screen.dart](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/scorer/tournaments/view/tournament_management_screen.dart)
    - Add `try-catch-finally` to `_save()`.
    - Use `Navigator.of(context).pop()` for more reliable navigation if `context.pop()` is failing.
    - Ensure the dashboard is refreshed correctly.

### 2. Fix Match Creation Loading
In `CreateLocalMatchScreen`, I will fix the "continuous loading" issue by ensuring the loading state is reset even if an error occurs.

- [MODIFY] [create_local_match_screen.dart](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/scorer/create_match/view/create_local_match_screen.dart)
    - Add `try-finally` block to `_createMatch()` to ensure `_isSaving` is set to `false` on completion or error.
    - Add error handling to show a snackbar if the match creation fails.

### 3. Improve Team Selection (Manual Entry)
In `MatchSetupScreen` (used for Friendly Matches), I will update the team picker to allow users to type team names manually, just like in the Local Match screen.

- [MODIFY] [match_setup_screen.dart](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/scorer/match_setup/view/match_setup_screen.dart)
    - Replace `DropdownButtonFormField` with a `TextFormField` that has a dropdown suffix icon.
    - Update `_teamPicker` to use `TextEditingController`s for manual entry.
    - Implement team resolution logic (finding existing team by name or creating a new temporary one) when proceeding to the next step.

## Verification Plan

### Automated Tests
- Run `dart analyze lib/` to ensure no regression in code quality.

### Manual Verification
1.  **Create Tournament:** Verify that clicking "Save" creates the tournament and immediately navigates back to the previous screen.
2.  **Create Match:** Verify that the "Creating..." state in the Local Match screen finishes correctly (either successful navigation or showing an error).
3.  **Friendly Match Team Entry:** Navigate to "Matches" in the Scorer hub, and verify you can now type team names manually in the "Team 1" and "Team 2" fields, as well as select them from the dropdown.
