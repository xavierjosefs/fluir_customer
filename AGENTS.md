# Fluir for Customers — Codex Instructions

## 1. Project Overview

Fluir for Customers is a Flutter mobile application for Android and iOS.

Fluir is a mobility platform concept similar to Uber, but designed around autonomous vehicles and additional services such as deliveries and professional services.

The current phase is a HIGH-FIDELITY INTERACTIVE PROTOTYPE.

There is currently NO real backend.

All data and system behavior must be mocked locally unless a future task explicitly requests backend integration.

---

## 2. Source of Truth

Before making UI, UX, architecture, or product decisions, review the project documentation.

Primary sources:

- `docs/design/fluir-ui-reference.png`
- `docs/research/fluir-customer-ux-research.pdf`

The approved UI reference is the visual source of truth.

The UX research document is the product/UX source of truth.

Do NOT independently redesign the product unless explicitly requested.

Do NOT ignore UX recommendations from the research document.

---

## 3. Product Scope

The application currently targets:

- Android
- iOS

The application must be designed mobile-first.

Do not optimize for:
- web
- desktop
- Windows
- tablets unless explicitly requested

The Windows target is not part of the product.

---

## 4. Current Technical Scope

Use:

- Flutter
- Dart
- Material 3
- go_router for navigation
- Riverpod for state management

Do not introduce a new architectural framework or state management library without explicit approval.

Do not introduce backend services unless explicitly requested.

Do not add Firebase, Supabase, REST APIs, GraphQL, authentication providers, maps SDKs, analytics SDKs, or payment SDKs without explicit approval.

---

## 5. Mocked Prototype Behavior

For this stage, all of the following must be simulated locally:

- users
- authentication
- OTP
- vehicles
- locations
- rides
- prices
- payment methods
- trip activity
- trip status
- delivery services
- professional services
- errors
- network-like loading states

Mock data should be isolated from the presentation layer.

Do not place large mock datasets directly inside screen widgets.

---

## 6. Architecture

Use a feature-first architecture.

Preferred structure:

lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── extensions/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── onboarding/
│   ├── authentication/
│   ├── home/
│   ├── ride/
│   ├── delivery/
│   ├── services/
│   ├── activity/
│   ├── payments/
│   ├── account/
│   └── support/
│
└── shared/
├── models/
└── widgets/

Each feature may contain:

- data/
- domain/
- presentation/

Presentation may contain:

- screens/
- widgets/
- controllers/

Do not create monolithic screen files.

Split reusable sections into appropriately named widgets.

Avoid premature abstraction.

---

## 7. Separation of Concerns

UI widgets must not contain unnecessary business logic.

Avoid:

- navigation logic scattered throughout widgets
- hardcoded app-wide colors
- hardcoded app-wide typography
- large lists of mock data inside widgets
- duplicated components
- duplicated constants
- service-specific logic inside generic shared widgets

Keep presentation, state, models, and mock data reasonably separated.

---

## 8. Visual Design — Mandatory

Follow the approved Fluir design explicitly.

The visual identity is based on the official Fluir wordmark and brand references.

### Fluir Brand Identity

The primary Fluir logo is the lowercase `fluir` wordmark.

The blue rounded-square graphic containing the wordmark is the APPLICATION ICON, not the primary in-app logo.

Do not confuse the application icon with the Fluir wordmark.

Inside the application UI, prefer the standalone Fluir wordmark whenever brand identification is required.

The Fluir wordmark may appear in approved contextual variants such as:

- White wordmark on Fluir blue
- Green wordmark on Fluir blue
- Dark wordmark on light surfaces

Do not invent or use unrelated symbols as the Fluir logo.

Never use the following as substitutes for the Fluir wordmark:

- Generic route symbols
- Abstract icons
- Shields
- Transportation icons
- Material icons
- Custom symbols invented by the implementation

If the exact Fluir wordmark asset is available, always use the official asset instead of recreating it with an arbitrary font.

Preserve:

- Lowercase lettering
- Original proportions
- Character shapes
- Spacing
- Visual weight

Do not:

- Stretch the wordmark
- Redraw it
- Approximate it using an unrelated typeface
- Add an icon beside it unless the official brand asset includes one
- Arbitrarily recolor it outside approved brand variants

The application icon may be used only where an actual app icon is contextually appropriate, such as:

- Android/iOS launcher icon
- App store representation
- Platform notification/app identity where appropriate

The application icon should generally NOT replace the standalone Fluir wordmark inside normal application screens.

Primary visual language:

- Fluir blue as the principal brand/action color
- Fluir green as secondary/supporting color
- white surfaces
- soft neutral gray backgrounds
- dark navy/near-black text
- clean line iconography
- rounded cards and controls
- subtle elevation
- generous whitespace

The final UI should feel:

- modern
- clean
- trustworthy
- premium
- simple
- safe
- technology-oriented
- mobility-oriented

Avoid:

- excessive gradients
- excessive shadows
- glassmorphism unless explicitly approved
- neon cyberpunk styling
- overly futuristic interfaces
- crowded cards
- tiny typography
- decorative elements without UX purpose

Do not invent a new branding direction.

### Contextual Brand Usage

Fluir branding must be intentional and contextual.

Do NOT force the Fluir wordmark onto every screen.

The wordmark should have strong prominence in brand-oriented moments such as:

- Splash
- Onboarding
- Welcome / brand introduction
- Selected marketing or empty-state experiences when appropriate

Task-oriented screens should prioritize clarity over repeated branding.

Examples of task-oriented screens include:

- Phone number entry
- OTP verification
- Error recovery
- Payment forms
- Destination search
- Ride confirmation

These screens do NOT require the Fluir wordmark simply for brand repetition.

The Fluir visual identity should remain recognizable through:

- Fluir blue
- Fluir green
- typography
- spacing
- component styling
- motion
- iconography
- consistent interaction patterns

Brand recognition should come from the complete design system, not from placing the logo on every screen.

For Authentication specifically:

- Onboarding may use strong Fluir branding.
- Phone and OTP screens should prioritize the task and may omit the wordmark.
- Do not insert a small floating wordmark without a clear compositional purpose.
- 
---

## 9. Design Tokens

Do not hardcode global design values repeatedly inside widgets.

Centralize:

- colors
- typography
- spacing
- radii
- shadows/elevation
- durations where appropriate

Expected files include:

- AppColors
- AppTypography
- AppSpacing
- AppRadius
- AppTheme

Prefer theme values and design tokens over arbitrary literal values.

---

## 10. Responsive Layout

The UI must work on common Android and iPhone screen sizes.

Do not design against a single fixed phone resolution.

Avoid unnecessary hardcoded:

- widths
- heights
- positions

Prefer:

- LayoutBuilder
- Expanded
- Flexible
- SafeArea
- MediaQuery when justified
- constraints

The layout must remain usable with different screen sizes and text scaling.

---

## 11. Android and iOS Compatibility

Every feature must be valid for both Android and iOS.

Always consider:

- SafeArea
- status bar
- navigation areas
- keyboard behavior
- back navigation
- scrolling
- text scaling
- platform conventions where appropriate

Do not implement Android-only behavior unless explicitly requested.

Do not implement iOS-only behavior unless explicitly requested.

Shared brand identity should remain consistent across both platforms.

---

## 12. Accessibility

Accessibility is part of the design, not a later enhancement.

Respect:

- readable contrast
- scalable text
- meaningful labels
- screen reader semantics where appropriate
- sufficiently large touch targets
- clear error messages
- visible selected states
- non-color-only state communication

Target approximately 48dp touch areas for important controls.

Do not rely only on color to communicate:

- success
- errors
- availability
- selection
- disabled states

---

## 13. Core Navigation

The main navigation is:

- Inicio
- Actividad
- Pagos
- Cuenta

This navigation must remain consistent unless a screen is intentionally part of a focused full-screen flow.

Use go_router.

Do not introduce an unrelated navigation pattern.

---

## 14. Home Information Architecture

Home must organize the product around user intention.

Primary categories:

- Viaje
- Envío
- Servicios

Do NOT return to the confusing previous taxonomy:

- Recogida
- Reparto
- Dron
- Trabajadores profesionales

Drone delivery should eventually exist as a delivery modality or availability option, not as an unrelated top-level category unless explicitly requested.

---

## 15. Service Availability

Never make an unavailable service look fully functional.

Services must clearly communicate their state before the user commits.

Supported states may include:

- Disponible
- Beta
- Próximamente
- No disponible en tu zona

Avoid UX dead ends.

If a service cannot continue, provide a useful next action where appropriate.

---

## 16. Primary Ride Flow

The main initial vertical is Ride.

Expected flow:

Home
→ Select Ride
→ Search destination
→ Confirm origin/destination
→ Vehicle options
→ Select payment method
→ Confirm ride
→ Searching for vehicle
→ Vehicle assigned
→ Vehicle arriving
→ Vehicle arrived
→ Ride in progress
→ Destination reached
→ Ride completed
→ Rating
→ Receipt

This must behave as a coherent end-to-end experience.

Do not implement disconnected screens.

---

## 17. Authentication / OTP UX

OTP is simulated locally in this prototype.

The UI should support meaningful states:

- phone entry
- sending
- code sent
- OTP input
- incorrect code
- expired code
- resend countdown
- edit phone number
- verified successfully

Avoid dead ends.

The user should be able to recover from an OTP problem without restarting the entire flow.

---

## 18. Error and Recovery States

Important user actions must account for states such as:

- idle
- loading
- success
- error

Where relevant, include:

- retry
- edit
- cancel
- go back
- alternative action
- support

Required prototype states include examples such as:

- no connection
- something went wrong
- no results
- payment failed
- service unavailable
- service coming soon
- incorrect OTP
- expired OTP

Do not create generic errors with no useful next action when a specific recovery action can be provided.

---

## 19. Maps

For the current prototype, do NOT integrate a real maps SDK unless explicitly requested.

Use a visual/mock implementation suitable for prototyping.

The mock map may represent:

- current location
- vehicles
- pickup
- destination
- routes
- movement/state changes

Keep the map implementation isolated so it can later be replaced by a real map provider.

The map is context for decision-making, not the entire interface.

Important actions should normally be surfaced using overlays, cards, or bottom sheets.

---

## 20. Components

Prefer reusable components for repeated UI patterns.

Potential shared components include:

- FluirButton
- FluirIconButton
- FluirTextField
- FluirSearchField
- FluirCard
- FluirServiceCard
- FluirVehicleCard
- FluirBottomSheet
- FluirStatusBadge
- FluirLocationField
- FluirNavigationBar
- FluirEmptyState
- FluirErrorState
- FluirLoadingState

Do not force every widget to become reusable.

Create shared components only when the pattern is actually repeated or clearly belongs to the design system.

---

## 21. Component States

Interactive components must consider relevant states.

Buttons may include:

- default
- pressed
- loading
- disabled

Inputs may include:

- default
- focused
- filled
- error
- disabled

Service items may include:

- available
- selected
- beta
- unavailable
- coming soon

Do not design only the ideal/default state.

---

## 22. Copy and Language

The product interface is currently Spanish.

Use clear, natural, concise Spanish.

Prefer:

- “Ingresa el código”
- “Cambiar número”
- “Reenviar en 00:30”
- “Confirmar viaje”
- “Servicio no disponible en tu zona”

Avoid unnatural or vague copy such as:

- “Introducir SMS”
- “Pronto habrá”
- generic messages that do not explain what happened

Do not change the app language globally unless explicitly requested.

---

## 23. Code Quality

Use idiomatic Dart and Flutter.

Prefer:

- const constructors where practical
- immutable data where appropriate
- small focused widgets
- meaningful class names
- readable code over clever code
- Dart naming conventions
- null safety
- current non-deprecated APIs

Avoid:

- massive build methods
- unnecessary nested widgets
- duplicated code
- magic numbers repeated throughout the app
- commented-out dead code
- unnecessary dependencies

---

## 24. Dependencies

Before adding a dependency:

1. Check whether Flutter/Dart already solves the problem adequately.
2. Ensure the dependency is actively maintained.
3. Ensure it supports Android and iOS.
4. Avoid introducing packages for trivial functionality.

Do not add dependencies without a clear purpose.

---

## 25. Scope Discipline

Implement only what the current task requests.

Do not use a task as an excuse to refactor unrelated modules.

Do not redesign unrelated screens.

Do not add speculative features.

Do not integrate backend functionality unless requested.

Do not expand the product scope without approval.

---

## 26. Validation Before Completion

Before declaring an implementation task complete:

Run:

```bash
dart format .
flutter analyze
flutter test
```

## 26. Validation Before Completion

Before declaring an implementation task complete:

Run:

```bash
dart format .
flutter analyze
flutter test
```
If tests do not yet exist for the affected area, state that clearly.

Fix analyzer errors caused by the task.

Do not knowingly leave new warnings or broken code.

When practical, verify the affected flow on an Android emulator.

---

## 27. Completion Report

At the end of every development task, provide a concise report containing:

1. What was implemented

2. Main files created or modified

3. Important design/architecture decisions

4. Validation performed

5. Any limitations or intentionally deferred items

Do not claim something was tested if it was not actually tested.

---

## 28. Git Safety

Do not:

- Reset unrelated user changes
- Overwrite unrelated files
- Delete code outside task scope
- Amend previous commits unless explicitly requested

Before large changes, inspect the repository and understand existing patterns.

Preserve working code outside the requested scope.

## 29. Priority Order

When requirements appear to conflict, use this priority:

1. Explicit current user request
2. Approved Fluir visual reference
3. Fluir UX research
4. AGENTS.md
5. Existing project architecture/patterns
6. General Flutter conventions

If an important conflict remains ambiguous, explain it instead of silently inventing a solution.

## 30. Core Product Principle

Fluir must prioritize:

CLARITY → COMPLETION → RECOVERY → CONSISTENCY → POLISH

A beautiful screen that creates a dead end is not acceptable.

A feature is not considered complete simply because its screen exists.

The user must understand:

- Where they are
- What they can do
- What will happen
- What the service costs when relevant
- Whether the service is available
- How to recover if something fails

