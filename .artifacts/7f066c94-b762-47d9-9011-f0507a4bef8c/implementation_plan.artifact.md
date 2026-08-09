# Implementation Plan - Google Sign-In Fix, Auth Theming, and Match Detail Improvements

This plan addresses the Google Sign-In "ApiException: 10" error, implements the "Continue with Google" button, makes ALL Auth screens theme-aware, and fixes the scorecard filter bug in the spectator match detail screen.

## User Review Required

> [!IMPORTANT]
> **Google Sign-In ApiException: 10**
> I have audited your configuration and found that the `android/app/google-services.json` file is missing the `oauth_client` array. This is the root cause of the error.
> - **Action Required**:
>   1. Go to Firebase Console > Project Settings > General.
>   2. Add the **SHA-1** fingerprint of your debug (and release) keystore.
>   3. Download the updated `google-services.json`.
>   4. Replace `android/app/google-services.json` with the new file.
> - **Note**: To find your debug SHA-1, run `./gradlew signingReport` in the `android` folder.

> [!CAUTION]
> **Theming Auth Screens**
> The `AuthScaffold` was previously hardcoded to always be light. I will change it to follow the app theme, so it will be light in Light mode and dark in Dark mode.

## Proposed Changes

### 1. Authentication Logic

#### [MODIFY] [AuthViewModel](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/auth/viewmodel/auth_viewmodel.dart)
- Implement `signInWithGoogle` to support direct login from the Sign In screen.

### 2. Theme-aware Auth Screens

#### [MODIFY] [AuthScaffold](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/auth/shared/auth_scaffold.dart)
- Remove hardcoded `AppColors.lightBackground` and `Colors.white`.
- Use `Theme.of(context).scaffoldBackgroundColor` and `Theme.of(context).colorScheme.surface`.
- Update gradients and decorative blurred circles to adapt to the current theme.

#### [MODIFY] [SignInScreen](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/auth/sign_in/view/sign_in_screen.dart)
- Refactor to use `AuthScaffold`.
- Add `GoogleSignInButton` below the "Sign In" button.

#### [MODIFY] [SignUpScreen](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/auth/view/sign_up_screen.dart)
- Add `GoogleSignInButton` below the "Sign Up" button.

#### [MODIFY] [ForgotPasswordScreen](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/auth/forgot_password/view/forgot_password_screen.dart)
- Update colors to use `Theme.of(context)` instead of `AppColors.darkBackground` and hardcoded white.

#### [MODIFY] [ScorerSignupScreen & SpectatorSignupScreen]
- Move `GoogleSignInButton` below the primary "Sign Up" / "Create Account" button.
- Ensure backgrounds follow the theme.

### 3. Spectator Match Detail Scorecard Fix

#### [MODIFY] [SpectatorMatchDetailScreen](file:///C:/Users/hp/Documents/GitHub/SportyApp/lib/ui/spectator/match_detail/view/spectator_match_detail_screen.dart)
- **Fix `_filteredInnings`**:
    - When a team is selected, show innings where they are **either batting or bowling**.
    - If Team B is selected and Team A is batting, Innings 1 should still be shown because Team B is bowling.
- **Fix `_inningsSection`**:
    - If a team filter is active and the selected team is BOWLING in that innings:
        - Add a "Bowling" indicator to the section header.
        - Ensure the Bowling card is shown correctly.
- **Fix "Next to Bat" squad display**:
    - Ensure the squad card clearly shows it belongs to the selected team.

## Verification Plan

### Automated Tests
- Run `dart analyze lib/` to ensure no linting or type errors.

### Manual Verification
1. **Auth Screens**:
   - Check `SignIn`, `SignUp`, `ForgotPassword`, and `RoleSelection` in both Light and Dark modes.
2. **Google Button**:
   - Confirm it appears below the primary button on all login/signup screens.
3. **Match Detail Filter**:
   - Start a live match.
   - Select the team that is currently bowling.
   - Verify that the scorecard shows their bowling stats and is correctly labeled.
