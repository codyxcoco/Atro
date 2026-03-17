# Lift Journal

Lift Journal is a native iPhone workout journal built with SwiftUI, SwiftData, EventKit, and HealthKit. The app is intentionally narrow: create a template, plan a workout, sync it to Calendar, log it quickly, add a short reflection, and revisit it in a calm journal-style history.

## Stack

- SwiftUI with modern Observation
- SwiftData for local-first persistence
- EventKit for one-way Calendar sync
- HealthKit for optional activity context and workout/state-of-mind export
- Async/await for permissions and integration flows
- XcodeGen for project generation

## Project setup

1. Generate the project:

```bash
xcodegen generate
```

2. Open the project:

```bash
open LiftJournal.xcodeproj
```

3. Build and run the `LiftJournal` scheme on an iPhone simulator.

Current local toolchain used for this project:

- Xcode 26.3
- iOS SDK 26.2
- Deployment target: iOS 26.0

## Test command

```bash
xcodebuild -project LiftJournal.xcodeproj -scheme LiftJournal -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Folder structure

```text
LiftJournal/
  App/                 App entry, root tabs, theme, app-level state
  Components/          Small reusable SwiftUI pieces and UIKit wrappers
  Features/
    Today/             Today dashboard and quick start entry points
    Plan/              Schedule view, template editor, planning sheets
    Logging/           Active workout session UI and summary flow
    Journal/           History, filters, entry detail, meal sheet
    Settings/          Feature toggles and integration settings
    Onboarding/        Short module-toggle onboarding
  Models/
    Supporting/        Snapshots, drafts, filters, helper types
  Services/
    Calendar/          EventKit sync, event payloads, ICS fallback export
    Health/            HealthKit authorization, summary reads, exports
    Data/              Seed/sample data bootstrapping
    System/            Haptics
  Preview/             In-memory preview container
  Resources/           Assets, entitlements, generated Info.plist
LiftJournalTests/      Unit tests for draft/model/sync helpers
```

## Architecture notes

- The app uses a lightweight feature-oriented MVVM style.
- SwiftUI views own presentation and local UX state.
- `@Observable` app/session objects handle integration state and active workout state.
- SwiftData stores durable records only. In-progress editing and workout logging use pure draft structs until the user saves.
- Planned workouts snapshot the template at schedule time so later template edits do not silently mutate already-planned days.

## Data model

Persisted models:

- `WorkoutTemplate`
- `ExerciseTemplate`
- `PlannedWorkout`
- `LoggedWorkout`
- `LoggedExercise`
- `LoggedSet`
- `MoodCheckIn`
- `MealEntry`
- `AppSettings`
- `CalendarSyncRecord`

Supporting non-persisted types:

- `TemplateSnapshot`
- `ExerciseSnapshot`
- `TemplateDraft`
- `ExerciseDraft`
- `WorkoutSessionDraft`
- `JournalFilter`

## MVP flow implemented

The current project supports the intended happy path:

1. Create or edit workout templates inside `Plan > Templates`.
2. Assign a template to a day in `Plan > Schedule`.
3. Optionally sync that planned workout to Calendar.
4. Start a workout from Today or the Plan list.
5. Log reps, weight, time, and quick set completion during the session.
6. Finish with notes, tags, and optional pre/post feeling check-ins.
7. Review entries in Journal with search and basic filtering.

## Calendar integration

- The app requests Calendar access only when the user enables Calendar sync or explicitly syncs a workout.
- The implementation uses EventKit write-only access for the MVP.
- If Calendar permission is denied, the app still works and falls back to exporting an `.ics` file through the share sheet.
- Calendar event notes include a deep link back into the app:

```text
liftjournal://planned-workout/<uuid>
```

## Health integration

- Health is off by default until enabled in onboarding or Settings.
- When enabled, the app can:
  - read today’s activity context (`activeEnergyBurned`, `appleExerciseTime`, workout count)
  - write completed workouts if the user opts in
  - write state-of-mind samples if the user opts into mood export
- If access is denied, the journal and workout flows stay fully usable.

## Permissions and entitlements

Info.plist usage strings:

- `NSCalendarsWriteOnlyAccessUsageDescription`
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

Entitlements:

- `com.apple.developer.healthkit`

## Sample data

On first launch the app seeds:

- two workout templates
- a planned workout for today
- a rest day
- another planned workout later in the week
- one logged workout with notes and mood check-ins
- one meal entry for previewing the optional meals section

This keeps previews and simulator runs useful from the first launch without hiding the empty states elsewhere in the app.

## Accessibility and native polish

- Large titles and grouped layouts throughout
- Dynamic Type-friendly text styles using the rounded system design
- Strong default contrast in light and dark appearances
- Large tap targets for primary controls
- Minimal modal stacking
- Lightweight haptic confirmation on save
- Reduced clutter when optional modules are turned off

## Branding notes

Accent and tint direction:

- Primary accent: warm copper (`AccentColor`)
- Light surfaces: parchment / soft stone
- Dark surfaces: charcoal / espresso
- Support colors: restrained neutral browns with a muted lift highlight

App icon direction:

- Minimal journal + dumbbell motif
- Light and dark icon variants included in `Assets.xcassets/AppIcon.appiconset`
- Geometric, native-feeling, and intentionally calm rather than aggressive

## Simplifying decisions

To keep the MVP focused, a few ambiguous areas intentionally lean simple:

- The Plan screen uses a lightweight date-strip + list view instead of a heavy custom month grid.
- Week duplication copies the selected week forward by 7 days.
- Manual workout start is template-based instead of introducing a separate large “manual builder” surface.
- Meal logging stays secondary and appears only when enabled.
- Calendar sync is one-way from the app to Calendar for MVP.

## Known follow-up opportunities

- Add a richer month calendar presentation if the product grows
- Add inline editing for logged journal entries after save
- Expand VoiceOver-specific hints on the workout logger rows
