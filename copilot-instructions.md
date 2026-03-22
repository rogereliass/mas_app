# MAS App - Copilot Instructions

## General Overview
MAS App is a community management tool for scouts and similar organizations, built with Flutter and Supabase. It features role-based access control, troop-scoped admin features, and a modern Material 3 design.

## Features & Modules

### Notifications Tab (Refined & Modernized)
The notifications system allows for sending and receiving targeted messages.
- **UI/UX**: Premium aesthetic with rounded corners (20px-24px), subtle gradients, and refined typography.
- **Stability**: Bulletproof layout designs using `Flexible`, `Expanded`, and `SingleChildScrollView` to prevent `RenderFlex` overflows on various screen sizes.

### Role Management (Enhanced UI/UX)
Centralized interface for managing user roles and permissions with senior-level UI polish.
- **Visuals**: Modern card-based layout with gradient avatars, integrated status badges, and icon-based information hierarchy.
- **Rank Indicators**: Professional neutral-themed badges (e.g., "Rank 60") replacing outdated "error-like" red circles.
- **Dialogs**: Clean, structured modals with distinct sections for "Assigned Roles" and "Editable Roles", featuring persistent state feedback and improved typography.
- **Filters**: Integrated, borderless search and filter bar using `surfaceContainerLow` for a lightweight feel.

### Admin Features
- Scoped data access for Troop Leaders (rank 60-70).
- System-wide access for Admins/Moderators (rank 90-100).
- Automatic troop-scoping via `ScopedServiceMixin` and context inference.

### User Acceptance (Modernized UI/UX)
- **Empty States & Fallbacks**: Blank DB fields visually render as *"Not provided"* natively dropping their font weight to `normal`, switching to `italic`, and fading to `onSurfaceVariant` rather than hiding the row entirely.
- **Section Headers**: Use stark, high-contrast anchors (e.g. navy blue `Color(0xFF001F3F)`) in light mode (`isDark ? onSurface : navyBlue`) to delineate major form groups.
- **Component Reusability**: Advanced unified widgets (like `RoleAssignmentSection`) track their own granular maps (e.g. `roleTroopContextMap`) making generic global state contexts obsolete. Leverage dummy entity constructors when transplanting complex components across modules.
- **Input Forms**: Forms feature precise bounds using explicit `OutlineInputBorder` matching `colorScheme.outlineVariant` (resting) and a strict 2px-weighted `colorScheme.primary` stroke (focused) for prominence. Inputs bind directly to precise contextual icons (e.g., `flag_outlined` for troops, `tag_outlined` for generations).

### User Management (Modernized UI/UX)
- **Edit Flow Structural Change**: Role assignment has been completely decoupled from the User Edit flow to simplify profile updates. Role management is now handled exclusively through the dedicated Role Management module.
- **Form Organization**: Multi-section forms using `_buildSectionHeader` with explicit icons (e.g., `person_outline`, `explore_outlined`) and high-contrast navy blue anchors for improved scannability.
- **Input Consistency**: Standardized 12px rounded corners across all text fields and dropdowns, with 2px primary-colored focus indicators.
- **User Cards**: Feature-rich cards with modern gradient avatars (based on user initials), persistent role badges, and a "Not provided" italic fallback for missing data fields.
- **Filters**: Standardized integrated search and filter bars with consistent border styling and 12px radius, ensuring a unified feel across admin modules.

## Coding Standards
- **UI**: Use Vanilla CSS/Flutter Material 3. Avoid hardcoded colors where possible, but use `withValues(alpha: ...)` on theme colors for subtle variations.
- **Layout Stability**: Always wrap flexible Row/Column children in `Flexible` or `Expanded` to avoid overflows.
- **State Management**: Provider.
- **Architecture**: Feature-based folder structure (Layered: UI, Logic, Data).
- **Search & Filter Patterns**:
  - Always implement a 400ms debounce for search inputs using `_lastSubmittedQuery` to prevent redundant network calls.
  - Normalize search inputs (trim) before processing.
  - Implement persistent dropdown caches in Providers (e.g., `_allTroops`) to ensure filter lists don't shrink or disappear when a result set is empty.
  - UI for filters should be borderless with 12px radius, using `surfaceContainerLow` as the fill color.
