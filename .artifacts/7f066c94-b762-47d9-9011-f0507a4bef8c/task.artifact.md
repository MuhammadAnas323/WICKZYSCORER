# Task List - Auth improvements and Match Detail Fixes

- [x] **Phase 1: Auth Logic & Infrastructure**
    - [x] Implement `signInWithGoogle` in `AuthViewModel`
    - [x] Audit `CurrentUserNotifier` for Google sign-in flow
    - [x] Fixed `applicationId` mismatch in `build.gradle.kts`
    - [x] Updated `firebase_options.dart` with correct Android App ID

- [x] **Phase 2: Theme-aware Auth UI**
    - [x] Update `AuthScaffold` to follow app theme
    - [x] Refactor `SignInScreen` to use `AuthScaffold` and add Google button
    - [x] Update `SignUpScreen` with Google button
    - [x] Update `ForgotPasswordScreen` colors
    - [x] Update `RoleSelectionScreen` colors
    - [x] Update `ScorerSignupScreen` & `SpectatorSignupScreen` to use `AuthScaffold`

- [x] **Phase 3: Match Detail Improvements**
    - [x] Fix scorecard filtering bug for bowling team in `SpectatorMatchDetailScreen`
    - [x] Improve innings section headers and labels with (Batting) and (Bowling) tags

- [x] **Phase 4: Verification**
    - [x] Run `dart analyze lib/`
    - [x] Fixed build errors in `sign_up_screen.dart` and `role_selection_screen.dart`
