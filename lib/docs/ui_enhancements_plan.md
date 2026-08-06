# UI & Theming Enhancements Plan

## Goal Description
Implement the new UI requirements, add custom points configuration, modify the tournament detail views, and switch the application default theme to a colorful Light Theme.

## User Review Required
- **Theming**: The app will default to Light Theme instead of Dark Theme. This will affect `main.dart` and `app_theme.dart`.
- **Colors**: As requested, we will use a vibrant palette (blue, green, red, yellow, cyan) for various buttons and widgets to ensure contrast and readability in the light theme.

## Proposed Changes

### Core & Theming
#### [MODIFY] `lib/main.dart`
- Change default theme mode to `ThemeMode.light`.

#### [MODIFY] `lib/theme/app_theme.dart` & `lib/theme/app_colors.dart`
- Update the Light Theme to be the primary focus.
- Add vibrant colors (Red, Blue, Yellow, Cyan, Green) for buttons, widgets, and texts.

---

### Scorer Portion
#### [MODIFY] `lib/ui/scorer/tournaments/view/tournament_management_screen.dart`
- Convert the hardcoded "Points Rules" text into editable `TextFormField`s (Win Points, Loss Points, Tie Points, No Result Points).
- Parse these inputs and save them into the `PointsRules` object when creating/updating the tournament.

---

### Spectator Portion
#### [MODIFY] `lib/ui/spectator/tournaments/view/tournament_details_screen.dart`
- Add a new button: "Rules, Requirements & Description".
- When clicked, display a dialog or bottom sheet containing the tournament's description, rules, and requirements.
- Remove the display of completed matches from the main screen, keeping the focus on upcoming matches, standings, and the dedicated "Schedules" tab.

#### [MODIFY] `lib/ui/spectator/tournaments/widgets/tournament_schedules_tab.dart` (or equivalent match list widget)
- Apply distinct color-coding for match states:
  - **Live**: Red
  - **Completed**: Green
  - **Upcoming**: Blue/Yellow

## Verification Plan
1. Launch the app and verify it defaults to a Light Theme with vibrant colors.
2. Go to Scorer -> Create Tournament and verify custom points can be entered and saved.
3. Open Spectator -> Tournament Details and verify the "Rules" button works.
4. Verify completed matches are removed from the main spectator view.
5. Check the Schedules tab to confirm Live, Upcoming, and Completed matches are correctly color-coded.
